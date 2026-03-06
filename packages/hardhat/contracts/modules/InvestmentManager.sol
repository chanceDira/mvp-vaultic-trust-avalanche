// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { UUPSUpgradeable }            from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Initializable }              from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable }         from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable }        from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { IERC20 }                     from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 }                  from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { VaulticAssetRegistry }             from "./VaulticAssetRegistry.sol";
import { VaulticFractionalOwnershipToken }  from "./VaulticFractionalOwnershipToken.sol";

/**
 * @title  VaulticInvestmentManager
 * @author @0xJonaseb11
 * @notice Economic engine of the Vaultic Trust protocol. Orchestrates the full
 *         lifecycle of fractional asset investment: tokenization, investor purchases,
 *         proceeds management, and — critically — the full-owner relisting flow that
 *         allows a single address holding 100 % of the ERC20 supply to close out the
 *         current offering and open a fresh one against the same registry entry.
 *
 * @dev    Architecture overview
 *         ──────────────────────
 *         This contract holds TOKENIZER_ROLE on VaulticAssetRegistry, giving it the
 *         authority to:
 *           • Deploy VaulticFractionalOwnershipToken proxies (tokenizeAsset).
 *           • Record tokenization metadata back to the registry.
 *           • Accept investor payments and forward shares atomically.
 *           • Accumulate proceeds for asset owners to pull.
 *           • Trigger registry closure when fully subscribed.
 *           • Verify full ownership, reclaim shares, update registry owner,
 *             and open a new offering round (relistAsset).
 *
 *         Payment currency is an ERC20 stablecoin (e.g. USDC on Avalanche C-Chain).
 *
 * @dev    Relisting flow (new in this version)
 *         ──────────────────────────────────────
 *         When a full owner (address holding 100 % of the ERC20 supply) wants to
 *         bring the asset back to market, they call relistAsset with new offering
 *         parameters. Internally the function executes this atomic sequence:
 *
 *           1. VERIFY    – caller's ERC20 balance == totalSupply().
 *           2. APPROVE   – caller grants this contract an allowance for their full balance.
 *                          (happens off-chain before calling; function reverts otherwise)
 *           3. RECLAIM   – all outstanding shares pulled back to this contract via
 *                          VaulticFractionalOwnershipToken.reclaimAllShares().
 *           4. OWN XFER  – registry.transferAssetOwnership() updates the on-chain owner.
 *           5. RELIST    – registry.relistAsset() resets per-round accounting and moves
 *                          state to RELISTED.
 *           6. TOKENIZE  – registry.recordTokenization() advances state to TOKENIZED
 *                          and locks in the new price + supply for the fresh round.
 *           7. POOL RESET– investment pool state is reset for the new round.
 *
 *         The entire sequence is nonReentrant and whenNotPaused. If any step reverts,
 *         the entire transaction reverts, keeping state consistent.
 *
 * @custom:security
 *         • ReentrancyGuard on all payment-handling and relist functions.
 *         • SafeERC20 wraps every ERC20 call.
 *         • Checks-Effects-Interactions strictly enforced.
 *         • Full-ownership check uses totalSupply() comparison — cannot be gamed.
 *         • Protocol fee hard cap: MAX_FEE_BPS (10 %).
 *         • Pull-over-push for proceeds withdrawals.
 *         • UUPS upgrade gate: only owner may authorize an implementation swap.
 *         • Storage gap (50 slots) prevents slot collisions in future versions.
 */
contract VaulticInvestmentManager is
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    // ─────────────────────────────────────────────────────────────────────────
    //  CUSTOM ERRORS
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Caller does not hold the required permission for this operation.
    error UnauthorizedCaller(address caller);

    /// @notice Asset is not in ACTIVE or RELISTED state; tokenization cannot proceed.
    error AssetNotEligibleForTokenization(uint256 assetId);

    /// @notice Asset is not in TOKENIZED state; purchases cannot proceed.
    error AssetNotOpenForInvestment(uint256 assetId);

    /// @notice Requested purchase share amount is zero.
    error ZeroPurchaseAmount();

    /// @notice Requested shares exceed the remaining supply in this round.
    error InsufficientSharesAvailable(uint256 requested, uint256 available);

    /// @notice Provided paymentAmount does not exactly match shareAmount × pricePerShare.
    error PaymentMismatch(uint256 expected, uint256 provided);

    /// @notice Total share supply for tokenization or relisting was set to zero.
    error InvalidShareSupply();

    /// @notice Price per share was set to zero.
    error InvalidPricePerShare();

    /// @notice A required address argument was the zero address.
    error ZeroAddressArgument(string field);

    /// @notice Purchase would push the investor over the per-asset investor cap.
    error InvestorCapExceeded(uint256 assetId, address investor, uint256 cap, uint256 requested);

    /// @notice No proceeds available to withdraw for this asset.
    error NoProceeds(uint256 assetId);

    /// @notice Caller is not the registered asset owner on the registry.
    error NotAssetOwner(uint256 assetId, address caller);

    /// @notice Protocol fee basis points exceed the maximum allowed (MAX_FEE_BPS).
    error FeeBpsExceedsMaximum(uint256 provided, uint256 maximum);

    /// @notice Caller does not hold 100 % of the ERC20 supply; cannot relist.
    error CallerDoesNotHoldFullSupply(uint256 assetId, address caller, uint256 balance, uint256 supply);

    /// @notice Asset is not in CLOSED state; relisting is not permitted.
    error AssetNotClosedForRelisting(uint256 assetId);

    // ─────────────────────────────────────────────────────────────────────────
    //  CONSTANTS
    // ─────────────────────────────────────────────────────────────────────────

    /// @dev    Basis-point denominator (10_000 = 100 %).
    uint256 private constant BPS_DENOMINATOR = 10_000;

    /// @dev    Maximum protocol fee: 10 % (1_000 bps). Guards investors against fee abuse.
    uint256 private constant MAX_FEE_BPS = 1_000;

    // ─────────────────────────────────────────────────────────────────────────
    //  STRUCTS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Per-asset investment pool state for the CURRENT offering round.
     *
     * @dev    Storage packing:
     *         Slot 0 – totalShares (128) + soldShares (128)
     *         Slot 1 – pricePerShare (128) + investorCap (128)
     *         Slot 2 – tokenContract (160) + isFullySubscribed (8) = 168 bits
     *         Slot 3 – proceedsCollected (256)
     *         Slot 4 – proceedsWithdrawn (256)
     *
     *         On relist all per-round fields (soldShares, isFullySubscribed,
     *         proceedsCollected, proceedsWithdrawn) are reset to zero.
     *         totalShares, pricePerShare, and investorCap are overwritten with new values.
     */
    struct AssetInvestmentPool {
        // ── Slot 0 ──────────────────────────────────────────────
        uint128 totalShares;          // Total shares in the current round
        uint128 soldShares;           // Running total purchased in the current round
        // ── Slot 1 ──────────────────────────────────────────────
        uint128 pricePerShare;        // Payment token units per share this round
        uint128 investorCap;          // Max shares per investor; 0 = uncapped
        // ── Slot 2 ──────────────────────────────────────────────
        address tokenContract;        // VaulticFractionalOwnershipToken proxy address
        bool    isFullySubscribed;    // True when soldShares == totalShares
        // ── Slot 3 ──────────────────────────────────────────────
        uint256 proceedsCollected;    // Net payment tokens received this round (post-fee)
        // ── Slot 4 ──────────────────────────────────────────────
        uint256 proceedsWithdrawn;    // Net payment tokens sent to asset owner this round
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  EVENTS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Emitted when a fractional ownership token is deployed and linked to an asset.
     * @param assetId       Registry identifier of the tokenized asset.
     * @param tokenContract Address of the deployed VaulticFractionalOwnershipToken proxy.
     * @param totalShares   Total supply of the fractional token for this round.
     * @param pricePerShare Payment token units per share for this round.
     */
    event AssetTokenized(
        uint256 indexed assetId,
        address indexed tokenContract,
        uint128 totalShares,
        uint128 pricePerShare
    );

    /**
     * @notice Emitted on every successful fractional share purchase.
     * @param assetId       Registry identifier of the underlying asset.
     * @param investor      Address of the purchasing investor.
     * @param shareAmount   Number of shares acquired.
     * @param paymentAmount Gross payment tokens transferred (before fee deduction).
     * @param feeTaken      Protocol fee deducted from the gross payment.
     */
    event FractionPurchased(
        uint256 indexed assetId,
        address indexed investor,
        uint256 shareAmount,
        uint256 paymentAmount,
        uint256 feeTaken
    );

    /**
     * @notice Emitted when an asset's offering round is fully subscribed.
     * @param assetId        Registry identifier.
     * @param totalProceeds  Cumulative net proceeds collected over this full round.
     */
    event OfferingFullySubscribed(
        uint256 indexed assetId,
        uint256 totalProceeds
    );

    /**
     * @notice Emitted when an asset owner withdraws their accumulated net proceeds.
     * @param assetId   Registry identifier.
     * @param recipient Asset owner's address.
     * @param amount    Payment token units transferred.
     */
    event ProceedsWithdrawn(
        uint256 indexed assetId,
        address indexed recipient,
        uint256 amount
    );

    /**
     * @notice Emitted when a full owner successfully relists a CLOSED asset.
     * @dev    Emitted AFTER the complete relist sequence (ownership transfer, registry
     *         relist, registry tokenization, pool reset) has executed without revert.
     *         This is the single authoritative signal that a new offering round is live.
     * @param assetId        Registry identifier of the relisted asset.
     * @param newOwner       Address of the full owner who triggered the relist.
     * @param newTotalShares Total shares in the new offering round.
     * @param newPricePerShare Price per share for the new offering round.
     * @param relistCount    Round number — sourced from registry.getRelistCount().
     */
    event AssetRelisted(
        uint256 indexed assetId,
        address indexed newOwner,
        uint128 newTotalShares,
        uint128 newPricePerShare,
        uint32  relistCount
    );

    /**
     * @notice Emitted when accumulated protocol fees are swept to the treasury.
     * @param treasury Recipient of fee proceeds.
     * @param amount   Payment token units transferred.
     */
    event FeesSweptToTreasury(address indexed treasury, uint256 amount);

    /**
     * @notice Emitted when the protocol fee rate is updated.
     * @param previousBps Former fee in basis points.
     * @param newBps      New fee in basis points.
     */
    event ProtocolFeeUpdated(uint256 previousBps, uint256 newBps);

    /**
     * @notice Emitted when the token implementation address is updated.
     * @param previous Former implementation.
     * @param updated  New implementation.
     */
    event TokenImplementationUpdated(address indexed previous, address indexed updated);

    // ─────────────────────────────────────────────────────────────────────────
    //  STORAGE
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Address of the VaulticAssetRegistry proxy.
    VaulticAssetRegistry public registry;

    /// @notice ERC20 stablecoin used for all investment payments (e.g. USDC).
    IERC20 public paymentToken;

    /// @notice Address of the VaulticFractionalOwnershipToken IMPLEMENTATION contract.
    ///         Proxies for each asset are deployed pointing to this address.
    address public tokenImplementation;

    /// @notice Protocol fee in basis points charged on each purchase.
    uint256 public protocolFeeBps;

    /// @notice Protocol treasury — receives accumulated fee proceeds on sweepProtocolFees.
    address public feeTreasury;

    /// @notice Total protocol fees accumulated across all assets, pending treasury sweep.
    uint256 public accumulatedFees;

    /// @notice Per-asset investment pool state for the current offering round.
    mapping(uint256 => AssetInvestmentPool) private _pools;

    /// @notice Per-asset, per-investor share balance tracker (current round only).
    /// @dev    Reset during relisting via _resetInvestorHoldings.
    mapping(uint256 => mapping(address => uint256)) public investorHoldings;

    /// @notice Tracks all investor addresses for each asset (for reclaimAllShares array).
    /// @dev    Addresses are pushed on purchase; never removed (used only for reclaim).
    mapping(uint256 => address[]) private _investorList;

    /// @dev    Reserved storage gap for future upgrades.
    uint256[50] private __gap;

    // ─────────────────────────────────────────────────────────────────────────
    //  MODIFIERS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Reverts if no investment pool exists for the supplied assetId.
     * @dev    Pools are created atomically during tokenizeAsset.
     */
    modifier poolExists(uint256 assetId) {
        if (_pools[assetId].tokenContract == address(0))
            revert AssetNotOpenForInvestment(assetId);
        _;
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  INITIALIZER
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Initializes the upgradeable proxy. Replaces the constructor.
     * @param  _registry            Address of the deployed VaulticAssetRegistry proxy.
     * @param  _paymentToken        ERC20 token used for all investment payments.
     * @param  _tokenImplementation Address of the VaulticFractionalOwnershipToken implementation.
     * @param  _feeTreasury         Protocol treasury receiving fee proceeds.
     * @param  _protocolFeeBps      Initial protocol fee in basis points (e.g. 50 = 0.5 %).
     * @param  _owner               Protocol owner address.
     */
    function initialize(
        address _registry,
        address _paymentToken,
        address _tokenImplementation,
        address _feeTreasury,
        uint256 _protocolFeeBps,
        address _owner
    ) external initializer {
        if (_registry            == address(0)) revert ZeroAddressArgument("registry");
        if (_paymentToken        == address(0)) revert ZeroAddressArgument("paymentToken");
        if (_tokenImplementation == address(0)) revert ZeroAddressArgument("tokenImplementation");
        if (_feeTreasury         == address(0)) revert ZeroAddressArgument("feeTreasury");
        if (_protocolFeeBps > MAX_FEE_BPS)      revert FeeBpsExceedsMaximum(_protocolFeeBps, MAX_FEE_BPS);

        __Ownable_init(_owner);
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        registry            = VaulticAssetRegistry(_registry);
        paymentToken        = IERC20(_paymentToken);
        tokenImplementation = _tokenImplementation;
        feeTreasury         = _feeTreasury;
        protocolFeeBps      = _protocolFeeBps;
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  TOKENIZATION
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Deploys a VaulticFractionalOwnershipToken proxy for an ACTIVE FRACTIONAL
     *         asset and records the tokenization on the registry.
     * @dev    Only the protocol owner may call this. A future iteration could allow
     *         verified asset owners to self-tokenize after depositing a security bond.
     * @param  assetId       Registry identifier of the asset to tokenize.
     * @param  totalShares   Total number of fractional shares to mint.
     * @param  pricePerShare Payment token units per share.
     * @param  investorCap   Maximum shares per investor (0 = uncapped).
     * @return tokenProxy    Address of the newly deployed token proxy.
     */
    function tokenizeAsset(
        uint256 assetId,
        uint128 totalShares,
        uint128 pricePerShare,
        uint128 investorCap
    )
        external
        onlyOwner
        whenNotPaused
        nonReentrant
        returns (address tokenProxy)
    {
        if (totalShares   == 0) revert InvalidShareSupply();
        if (pricePerShare == 0) revert InvalidPricePerShare();

        VaulticAssetRegistry.AssetRecord memory rec = registry.getAsset(assetId);

        if (rec.state != VaulticAssetRegistry.AssetState.ACTIVE)
            revert AssetNotEligibleForTokenization(assetId);

        if (rec.model != VaulticAssetRegistry.OwnershipModel.FRACTIONAL)
            revert AssetNotEligibleForTokenization(assetId);

        tokenProxy = _deployTokenProxy();

        VaulticFractionalOwnershipToken(tokenProxy).initialize(
            assetId,
            rec.assetName,
            totalShares,
            address(this),  // initial holder: InvestmentManager holds all shares
            address(this),  // authorizedMinter: InvestmentManager dispatches shares
            owner()
        );

        AssetInvestmentPool storage pool = _pools[assetId];
        pool.totalShares   = totalShares;
        pool.pricePerShare = pricePerShare;
        pool.investorCap   = investorCap;
        pool.tokenContract = tokenProxy;

        registry.recordTokenization(assetId, tokenProxy, totalShares, pricePerShare);

        emit AssetTokenized(assetId, tokenProxy, totalShares, pricePerShare);
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  INVESTMENT
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Purchases `shareAmount` fractional shares of a TOKENIZED asset.
     *
     * @dev    Full execution sequence (strict Checks-Effects-Interactions):
     *
     *         Checks:
     *           • Pool exists and is not fully subscribed.
     *           • shareAmount > 0.
     *           • Remaining supply ≥ shareAmount.
     *           • Investor cap not exceeded (if set).
     *           • paymentAmount exactly equals shareAmount × pricePerShare.
     *
     *         Effects (all state mutations BEFORE external calls):
     *           • pool.soldShares += shareAmount.
     *           • investorHoldings updated.
     *           • isFullySubscribed flagged if this purchase clears the supply.
     *           • proceedsCollected += netCost.
     *           • accumulatedFees  += fee.
     *
     *         Interactions:
     *           • Pull gross payment from investor via safeTransferFrom.
     *           • Dispatch shares via VaulticFractionalOwnershipToken.dispatchShares.
     *           • Update registry sold-share counter.
     *           • Auto-close registry if fully subscribed.
     *
     * @param  assetId       Registry identifier of the asset to invest in.
     * @param  shareAmount   Number of shares to purchase.
     * @param  paymentAmount Exact gross payment in payment token units. Must equal
     *                       shareAmount × pricePerShare. Explicit parameter prevents
     *                       silent manipulation if pricePerShare were ever updated.
     */
    function purchaseShares(
        uint256 assetId,
        uint256 shareAmount,
        uint256 paymentAmount
    )
        external
        whenNotPaused
        nonReentrant
        poolExists(assetId)
    {
        // ── Checks ───────────────────────────────────────────────
        if (shareAmount == 0) revert ZeroPurchaseAmount();

        AssetInvestmentPool storage pool = _pools[assetId];

        if (pool.isFullySubscribed) revert AssetNotOpenForInvestment(assetId);

        uint256 remaining = pool.totalShares - pool.soldShares;
        if (shareAmount > remaining)
            revert InsufficientSharesAvailable(shareAmount, remaining);

        if (pool.investorCap != 0) {
            uint256 current = investorHoldings[assetId][msg.sender];
            if (current + shareAmount > pool.investorCap)
                revert InvestorCapExceeded(assetId, msg.sender, pool.investorCap, shareAmount);
        }

        uint256 grossCost = uint256(pool.pricePerShare) * shareAmount;
        if (paymentAmount != grossCost) revert PaymentMismatch(grossCost, paymentAmount);

        // ── Effects ──────────────────────────────────────────────
        uint256 fee     = (grossCost * protocolFeeBps) / BPS_DENOMINATOR;
        uint256 netCost = grossCost - fee;

        pool.soldShares        += uint128(shareAmount);
        pool.proceedsCollected += netCost;
        accumulatedFees        += fee;

        // Track new investor address for reclaimAllShares later
        if (investorHoldings[assetId][msg.sender] == 0) {
            _investorList[assetId].push(msg.sender);
        }
        investorHoldings[assetId][msg.sender] += shareAmount;

        bool fullySub = pool.soldShares == pool.totalShares;
        if (fullySub) pool.isFullySubscribed = true;

        // ── Interactions ─────────────────────────────────────────
        paymentToken.safeTransferFrom(msg.sender, address(this), grossCost);

        VaulticFractionalOwnershipToken(pool.tokenContract)
            .dispatchShares(msg.sender, shareAmount);

        registry.recordSharesSold(assetId, uint128(shareAmount));

        emit FractionPurchased(assetId, msg.sender, shareAmount, grossCost, fee);

        if (fullySub) {
            registry.closeAsset(assetId);
            emit OfferingFullySubscribed(assetId, pool.proceedsCollected);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  RELISTING   (NEW)
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Allows a full owner (holder of 100 % ERC20 supply) to relist a CLOSED
     *         asset for a brand-new investment round without creating a new registry entry.
     *
     * @dev    Atomically executes the full relist sequence in a single transaction:
     *
     *           Step 1 – VERIFY full ownership
     *             Reverts with CallerDoesNotHoldFullSupply if caller's balance < totalSupply.
     *
     *           Step 2 – RECLAIM all outstanding shares
     *             Calls VaulticFractionalOwnershipToken.reclaimAllShares with the full
     *             investor list accumulated from prior purchases. This burns no tokens —
     *             shares are simply transferred back to this contract (the minter).
     *             After this step, address(this) holds 100 % of the supply.
     *
     *           Step 3 – TRANSFER on-chain ownership
     *             Calls registry.transferAssetOwnership(assetId, msg.sender).
     *             The full owner is now the registry-recognised assetOwner.
     *
     *           Step 4 – RELIST in registry
     *             Calls registry.relistAsset() which transitions state CLOSED → RELISTED,
     *             resets per-round accounting fields, and increments the relistCount.
     *
     *           Step 5 – RECORD new tokenization
     *             Calls registry.recordTokenization() which advances state RELISTED → TOKENIZED
     *             and sets the new totalShares and pricePerShare for this round.
     *
     *           Step 6 – RESET investment pool
     *             All pool accounting fields are reset and populated with new round values.
     *             The investor list is cleared so it rebuilds cleanly from new purchases.
     *
     *         Security notes:
     *           • nonReentrant guards the entire sequence.
     *           • The full-ownership check uses totalSupply() — it cannot be gamed by
     *             temporarily borrowing tokens because the check and reclaim are atomic.
     *           • The caller must hold ALL shares including any they dispatched to themselves
     *             or transferred from other investors. There is no partial relist.
     *           • proceedsWithdrawn from the previous round is preserved as historical
     *             accounting data but proceedsCollected is reset to zero for the new round.
     *
     * @param  assetId          Registry identifier of the CLOSED asset to relist.
     * @param  newTotalShares   Total share supply for the new offering round.
     * @param  newPricePerShare Price per share in payment token units for the new round.
     * @param  newValuation     Updated USD valuation for the new round.
     * @param  newMetadataURI   Updated IPFS/Arweave URI for fresh legal documents.
     * @param  newInvestorCap   Per-investor cap for the new round (0 = uncapped).
     */
    function relistAsset(
        uint256         assetId,
        uint128         newTotalShares,
        uint128         newPricePerShare,
        uint128         newValuation,
        string calldata newMetadataURI,
        uint128         newInvestorCap
    )
        external
        whenNotPaused
        nonReentrant
        poolExists(assetId)
    {
        // ── Checks ───────────────────────────────────────────────
        if (newTotalShares   == 0) revert InvalidShareSupply();
        if (newPricePerShare == 0) revert InvalidPricePerShare();

        // Asset must be CLOSED for relisting to be valid
        VaulticAssetRegistry.AssetRecord memory rec = registry.getAsset(assetId);
        if (rec.state != VaulticAssetRegistry.AssetState.CLOSED)
            revert AssetNotClosedForRelisting(assetId);

        // Caller must hold 100 % of the ERC20 supply — full economic ownership required
        VaulticFractionalOwnershipToken token = VaulticFractionalOwnershipToken(
            _pools[assetId].tokenContract
        );
        uint256 supply        = token.totalSupply();
        uint256 callerBalance = token.balanceOf(msg.sender);

        if (callerBalance != supply)
            revert CallerDoesNotHoldFullSupply(assetId, msg.sender, callerBalance, supply);

        // ── Effects (state writes before interactions) ────────────
        // Reset investment pool for the new round
        AssetInvestmentPool storage pool = _pools[assetId];
        pool.totalShares       = newTotalShares;
        pool.soldShares        = 0;
        pool.pricePerShare     = newPricePerShare;
        pool.investorCap       = newInvestorCap;
        pool.isFullySubscribed = false;
        pool.proceedsCollected = 0;
        pool.proceedsWithdrawn = 0;

        // Clear the investor holdings map for the new round.
        // We iterate the stored investor list — the same list used for reclaim below.
        address[] storage investors = _investorList[assetId];
        uint256 investorCount       = investors.length;

        for (uint256 i; i < investorCount; ) {
            investorHoldings[assetId][investors[i]] = 0;
            unchecked { ++i; }
        }

        // Clear the investor list (will rebuild fresh from new purchases)
        delete _investorList[assetId];

        // ── Interactions ─────────────────────────────────────────
        // Step 2: Pull all shares back to this contract from every holder.
        // reclaimAllShares uses _transfer internally — no allowance required
        // because this contract is the authorizedMinter on the token.
        // Build reclaim list: caller + any other prior holders in investorList.
        // We already have `investors` snapshot above; add the caller separately
        // since they may not be in the historic investor list (acquired via secondary).
        address[] memory reclaimList;
        if (investorCount > 0) {
            // Caller might be one of the investors — reclaimAllShares handles zero-balance skip
            reclaimList = new address[](investorCount + 1);
            for (uint256 i; i < investorCount; ) {
                reclaimList[i] = investors[i];
                unchecked { ++i; }
            }
            reclaimList[investorCount] = msg.sender;
        } else {
            reclaimList = new address[](1);
            reclaimList[0] = msg.sender;
        }

        token.reclaimAllShares(reclaimList);

        // Step 3: Transfer registry ownership to the new full owner
        registry.transferAssetOwnership(assetId, msg.sender);

        // Step 4: Transition registry state CLOSED → RELISTED and reset registry fields
        registry.relistAsset(assetId, newValuation, newMetadataURI);

        // Step 5: Advance registry state RELISTED → TOKENIZED with new round parameters
        registry.recordTokenization(
            assetId,
            address(token),  // same ERC20 proxy is reused for the new round
            newTotalShares,
            newPricePerShare
        );

        // Retrieve the updated relistCount from registry for the event
        uint32 relistCount = registry.getRelistCount(assetId);

        emit AssetRelisted(assetId, msg.sender, newTotalShares, newPricePerShare, relistCount);
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  PROCEEDS MANAGEMENT
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Allows the registered asset owner to withdraw accumulated net proceeds.
     * @dev    Pull-over-push: funds are never pushed automatically to avoid failed
     *         transfers blocking the investment flow. Proceeds from the CURRENT round
     *         only — previous rounds' proceeds are separate historical accounting.
     * @param  assetId Registry identifier of the asset whose proceeds to withdraw.
     */
    function withdrawProceeds(uint256 assetId)
        external
        whenNotPaused
        nonReentrant
        poolExists(assetId)
    {
        VaulticAssetRegistry.AssetRecord memory rec = registry.getAsset(assetId);
        if (msg.sender != rec.assetOwner) revert NotAssetOwner(assetId, msg.sender);

        AssetInvestmentPool storage pool = _pools[assetId];
        uint256 withdrawable = pool.proceedsCollected - pool.proceedsWithdrawn;
        if (withdrawable == 0) revert NoProceeds(assetId);

        pool.proceedsWithdrawn += withdrawable;

        paymentToken.safeTransfer(msg.sender, withdrawable);

        emit ProceedsWithdrawn(assetId, msg.sender, withdrawable);
    }

    /**
     * @notice Sweeps all accumulated protocol fees to the feeTreasury address.
     * @dev    Owner-only. Fee custody is held here to minimize cross-contract calls
     *         on the hot purchaseShares path. This is a periodic governance sweep.
     */
    function sweepProtocolFees() external onlyOwner nonReentrant {
        uint256 amount = accumulatedFees;
        if (amount == 0) revert NoProceeds(0);

        accumulatedFees = 0;
        paymentToken.safeTransfer(feeTreasury, amount);

        emit FeesSweptToTreasury(feeTreasury, amount);
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  ADMIN
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Updates the protocol fee rate.
     * @dev    Changes apply to future purchases only. Hard cap: MAX_FEE_BPS (10 %).
     * @param  newFeeBps New fee in basis points.
     */
    function setProtocolFee(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert FeeBpsExceedsMaximum(newFeeBps, MAX_FEE_BPS);
        uint256 prev   = protocolFeeBps;
        protocolFeeBps = newFeeBps;
        emit ProtocolFeeUpdated(prev, newFeeBps);
    }

    /**
     * @notice Updates the fee treasury recipient address.
     * @param  newTreasury New treasury address.
     */
    function setFeeTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert ZeroAddressArgument("feeTreasury");
        feeTreasury = newTreasury;
    }

    /**
     * @notice Updates the VaulticFractionalOwnershipToken implementation for future deploys.
     * @dev    Only affects future token proxy deployments — does NOT retroactively upgrade
     *         existing proxies. Use upgradeTo on each token proxy directly for that.
     * @param  newImplementation New implementation address.
     */
    function setTokenImplementation(address newImplementation) external onlyOwner {
        if (newImplementation == address(0)) revert ZeroAddressArgument("tokenImplementation");
        address prev        = tokenImplementation;
        tokenImplementation = newImplementation;
        emit TokenImplementationUpdated(prev, newImplementation);
    }

    /// @notice Emergency pause — halts all purchases, relists, and withdrawals.
    function pause() external onlyOwner { _pause(); }

    /// @notice Resumes normal operation after an emergency pause.
    function unpause() external onlyOwner { _unpause(); }

    // ─────────────────────────────────────────────────────────────────────────
    //  VIEW FUNCTIONS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @notice Returns the investment pool state for the current offering round.
     * @param  assetId Asset to query.
     * @return pool    Full AssetInvestmentPool struct (memory copy).
     */
    function getInvestmentPool(uint256 assetId)
        external
        view
        poolExists(assetId)
        returns (AssetInvestmentPool memory pool)
    {
        pool = _pools[assetId];
    }

    /**
     * @notice Computes the gross cost, fee, and net cost for a prospective purchase.
     * @param  assetId     Asset to price.
     * @param  shareAmount Number of shares to price.
     * @return grossCost   Total gross payment tokens required (what caller must approve).
     * @return fee         Protocol fee component within grossCost.
     * @return netCost     Net proceeds component (grossCost − fee).
     */
    function quotePurchase(uint256 assetId, uint256 shareAmount)
        external
        view
        poolExists(assetId)
        returns (uint256 grossCost, uint256 fee, uint256 netCost)
    {
        AssetInvestmentPool storage pool = _pools[assetId];
        grossCost = uint256(pool.pricePerShare) * shareAmount;
        fee       = (grossCost * protocolFeeBps) / BPS_DENOMINATOR;
        netCost   = grossCost - fee;
    }

    /**
     * @notice Returns shares still available for purchase in the current round.
     * @param  assetId Asset identifier.
     * @return available Remaining unsold shares.
     */
    function availableShares(uint256 assetId)
        external
        view
        poolExists(assetId)
        returns (uint256 available)
    {
        AssetInvestmentPool storage pool = _pools[assetId];
        available = pool.totalShares - pool.soldShares;
    }

    /**
     * @notice Returns shares held by a specific investor for an asset in the current round.
     * @param  assetId  Asset identifier.
     * @param  investor Investor address.
     * @return shares   Share count (current round only; resets on relist).
     */
    function getInvestorHoldings(uint256 assetId, address investor)
        external
        view
        returns (uint256 shares)
    {
        shares = investorHoldings[assetId][investor];
    }

    /**
     * @notice Returns withdrawable net proceeds for the registered asset owner.
     * @param  assetId Asset identifier.
     * @return amount  Withdrawable payment token units.
     */
    function withdrawableProceeds(uint256 assetId)
        external
        view
        poolExists(assetId)
        returns (uint256 amount)
    {
        AssetInvestmentPool storage pool = _pools[assetId];
        amount = pool.proceedsCollected - pool.proceedsWithdrawn;
    }

    /**
     * @notice Returns the full list of investor addresses who participated in the current round.
     * @dev    Used internally for reclaimAllShares; also exposed for off-chain tooling.
     * @param  assetId Asset identifier.
     * @return list    Array of investor addresses.
     */
    function getInvestorList(uint256 assetId)
        external
        view
        returns (address[] memory list)
    {
        list = _investorList[assetId];
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  INTERNAL HELPERS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * @dev    Deploys an EIP-1167 minimal proxy clone pointing to tokenImplementation.
     *         ~45 bytes of bytecode vs several kilobytes of a full contract copy.
     *         Each asset gets its own proxy instance; all share one implementation.
     * @return proxy Address of the newly deployed proxy contract.
     */
    function _deployTokenProxy() internal returns (address proxy) {
        address impl = tokenImplementation;

        assembly {
            let ptr := mload(0x40)
            mstore(ptr,         0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 20), shl(96, impl))
            mstore(add(ptr, 40), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            proxy := create(0, ptr, 55)
        }

        if (proxy == address(0)) revert ZeroAddressArgument("tokenProxy");
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  UUPS UPGRADE AUTHORIZATION
    // ─────────────────────────────────────────────────────────────────────────

    /// @dev Restricts upgrade authority to the contract owner.
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {} // solhint-disable-line no-empty-blocks
}
