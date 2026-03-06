// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/**
 * @title VaulticAssetRegistry
 * @author @0xJonaseb11
 * @notice Registry for real-world assets tokenized through the Vaultic Trust protocol.
 */
contract VaulticAssetRegistry is Initializable, OwnableUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    
    error UnauthorizedCaller(address caller);
    error AssetAlreadyRegistered(uint256 assetId);
    error InvalidStateTransition(uint256 assetId, AssetState current, AssetState requested);
    error EmptyStringField(string fieldName);
    error InvalidValuation(uint256 provided);
    error AssetNotFound(uint256 assetId);
    error AssetNotActiveForTokenization(uint256 assetId, AssetState current);
    error InvalidShareSupply(uint256 provided);
    error InvalidTokenPrice(uint256 provided);
    error InvalidTokenContractAddress();
    error OwnershipModelMismatch(uint256 assetId, OwnershipModel model);

    enum AssetState {
        PENDING,
        ACTIVE,
        TOKENIZED,
        CLOSED
    }

    enum OwnershipModel {
        WHOLE_OWNERSHIP,
        FRACTIONAL
    }

    struct AssetRecord {
        uint256 assetId;
        address assetOwner;
        AssetState state;
        OwnershipModel model;
        uint48 registeredAt;
        uint128 valuation;
        uint128 totalShares;
        uint128 pricePerShare;
        uint128 soldShares;
        address tokenContract;
        uint48 tokenizedAt;
        string assetName;
        string assetCategory;
        string metadataURI;
    }

    event AssetRegistered(
        uint256 indexed assetId,
        address indexed assetOwner,
        string assetName,
        string assetCategory,
        uint128 valuation,
        OwnershipModel model
    );

    event AssetApproved(uint256 indexed assetId, address indexed approvedBy);
    event AssetTokenized(
        uint256 indexed assetId,
        address indexed tokenContract,
        uint128 totalShares,
        uint128 pricePerShare
    );
    event AssetClosed(uint256 indexed assetId, address indexed closedBy);
    event SoldSharesUpdated(uint256 indexed assetId, uint128 soldShares);
    event TokenizerUpdated(address indexed previous, address indexed updated);

    address public tokenizer;
    uint96 private _assetCounter;
    mapping(uint256 => AssetRecord) private _assets;
    mapping(address => uint256[]) private _ownerAssets;
    mapping(bytes32 => bool) private _registrationGuard;
    uint256[50] private __gap;

    modifier onlyTokenizer() {
        if (msg.sender != tokenizer) revert UnauthorizedCaller(msg.sender);
        _;
    }

    modifier assetExists(uint256 assetId) {
        if (_assets[assetId].assetId == 0) revert AssetNotFound(assetId);
        _;
    }

    /**
     * @notice Initializes the upgradeable proxy.
     * @param initialOwner Address that will own the registry.
     * @param initialTokenizer Address allowed to record tokenization and sales.
     */
    function initialize(address initialOwner, address initialTokenizer) external initializer {
        __Ownable_init(initialOwner);
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        if (initialTokenizer == address(0)) revert InvalidTokenContractAddress();

        tokenizer = initialTokenizer;
        _assetCounter = 1;
    }

    /**
     * @notice Grants TOKENIZER_ROLE to a new address.
     * @param newTokenizer Address to assign as tokenizer.
     */
    function setTokenizer(address newTokenizer) external onlyOwner {
        if (newTokenizer == address(0)) revert InvalidTokenContractAddress();
        address prev = tokenizer;
        tokenizer = newTokenizer;
        emit TokenizerUpdated(prev, newTokenizer);
    }

    /**
     * @notice Registers a new real-world asset.
     * @dev Owner-only; deduplicated by (name, category, metadataURI, owner).
     * @param assetOwner Address of the asset owner.
     * @param assetName Human-readable asset name.
     * @param assetCategory Category label (e.g. "Real Estate").
     * @param metadataURI URI for off-chain documentation.
     * @param valuation Asset valuation in configured units.
     * @param model Ownership model (whole or fractional).
     * @return assetId Newly assigned asset identifier.
     */
    function registerAsset(
        address assetOwner,
        string calldata assetName,
        string calldata assetCategory,
        string calldata metadataURI,
        uint128 valuation,
        OwnershipModel model
    ) external onlyOwner whenNotPaused nonReentrant returns (uint256 assetId) {
        if (assetOwner == address(0)) revert UnauthorizedCaller(address(0));
        if (bytes(assetName).length == 0) revert EmptyStringField("assetName");
        if (bytes(assetCategory).length == 0) revert EmptyStringField("assetCategory");
        if (bytes(metadataURI).length == 0) revert EmptyStringField("metadataURI");
        if (valuation == 0) revert InvalidValuation(0);

        bytes32 guard = keccak256(abi.encodePacked(assetName, assetCategory, metadataURI, assetOwner));
        if (_registrationGuard[guard]) revert AssetAlreadyRegistered(0); // assetId unknown yet

        assetId = _assetCounter++;
        _registrationGuard[guard] = true;

        AssetRecord storage rec = _assets[assetId];
        rec.assetId = assetId;
        rec.assetOwner = assetOwner;
        rec.state = AssetState.PENDING;
        rec.model = model;
        rec.registeredAt = uint48(block.timestamp);
        rec.valuation = valuation;
        rec.assetName = assetName;
        rec.assetCategory = assetCategory;
        rec.metadataURI = metadataURI;

        _ownerAssets[assetOwner].push(assetId);
        emit AssetRegistered(assetId, assetOwner, assetName, assetCategory, valuation, model);
    }

    /**
     * @notice Transitions an asset from PENDING to ACTIVE, enabling investment.
     * @param assetId Asset identifier.
     */
    function approveAsset(uint256 assetId) external onlyOwner whenNotPaused assetExists(assetId) {
        AssetRecord storage rec = _assets[assetId];
        _requireTransition(assetId, rec.state, AssetState.ACTIVE);

        rec.state = AssetState.ACTIVE;

        emit AssetApproved(assetId, msg.sender);
    }

    /**
     * @notice Records tokenization details for a fractional asset and marks it TOKENIZED.
     * @param assetId Asset identifier.
     * @param tokenContract Fractional ERC20 token address.
     * @param totalShares Total token supply representing 100% ownership.
     * @param pricePerShare Price per share in the chosen payment token.
     */
    function recordTokenization(
        uint256 assetId,
        address tokenContract,
        uint128 totalShares,
        uint128 pricePerShare
    ) external onlyTokenizer whenNotPaused assetExists(assetId) {
        AssetRecord storage rec = _assets[assetId];

        if (rec.model != OwnershipModel.FRACTIONAL) revert OwnershipModelMismatch(assetId, rec.model);
        if (rec.state != AssetState.ACTIVE) revert AssetNotActiveForTokenization(assetId, rec.state);
        if (tokenContract == address(0)) revert InvalidTokenContractAddress();
        if (totalShares == 0) revert InvalidShareSupply(0);
        if (pricePerShare == 0) revert InvalidTokenPrice(0);

        rec.state = AssetState.TOKENIZED;
        rec.tokenContract = tokenContract;
        rec.totalShares = totalShares;
        rec.pricePerShare = pricePerShare;
        rec.tokenizedAt = uint48(block.timestamp);

        emit AssetTokenized(assetId, tokenContract, totalShares, pricePerShare);
    }

    /**
     * @notice Increments the sold-share counter for a fractional asset.
     * @param assetId Asset identifier.
     * @param sharesDelta Number of newly sold shares.
     */
    function recordSharesSold(uint256 assetId, uint128 sharesDelta) external onlyTokenizer assetExists(assetId) {
        if (sharesDelta == 0) revert InvalidShareSupply(0);

        AssetRecord storage rec = _assets[assetId];
        uint128 updated = rec.soldShares + sharesDelta;
        rec.soldShares = updated;

        emit SoldSharesUpdated(assetId, updated);
    }

    /**
     * @notice Marks an asset as CLOSED, ending further investment activity.
     * @param assetId Asset identifier.
     */
    function closeAsset(uint256 assetId) external whenNotPaused assetExists(assetId) {
        if (msg.sender != owner() && msg.sender != tokenizer) revert UnauthorizedCaller(msg.sender);
        AssetRecord storage rec = _assets[assetId];
        if (rec.state == AssetState.PENDING || rec.state == AssetState.CLOSED)
           revert InvalidStateTransition(assetId, rec.state, AssetState.CLOSED);

        rec.state = AssetState.CLOSED;
        emit AssetClosed(assetId, msg.sender);
    }

    // ================================== //
    //  ============ GETTERS ============ // 
    //  =================================== //
    function getAsset(uint256 assetId) external view assetExists(assetId) returns (AssetRecord memory rec) {
        rec = _assets[assetId];
    }

    function getAssetsByOwner(address assetOwner) external view returns (uint256[] memory ids) {
        ids = _ownerAssets[assetOwner];
    }

    /// @notice Returns the current state of an asset.
    function getAssetState(uint256 assetId) external view assetExists(assetId) returns (AssetState) {
        return _assets[assetId].state;
    }

    /// @notice Returns current funding progress as (soldShares, totalShares).
    function getFundingProgress(
        uint256 assetId
    ) external view assetExists(assetId) returns (uint128 soldShares, uint128 totalShares) {
        AssetRecord storage rec = _assets[assetId];
        soldShares = rec.soldShares;
        totalShares = rec.totalShares;
    }

    /// @notice Returns the total number of assets that have ever been registered.
    function totalAssets() external view returns (uint256 count) {
        count = _assetCounter - 1;
    }

    /// @dev Validates that a state transition is permitted by the lifecycle FSM.
    function _requireTransition(uint256 assetId, AssetState current, AssetState requested) internal pure {
        bool valid;
        if (current == AssetState.PENDING && requested == AssetState.ACTIVE) valid = true;
        if (current == AssetState.ACTIVE && requested == AssetState.TOKENIZED) valid = true;
        if (current == AssetState.ACTIVE && requested == AssetState.CLOSED) valid = true;
        if (current == AssetState.TOKENIZED && requested == AssetState.CLOSED) valid = true;

        if (!valid) revert InvalidStateTransition(assetId, current, requested);
    }

    /// @dev UUPS hook; restricts upgrades to the contract owner.
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {} 


        /// @notice Pauses all state-changing operations.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract.
    function unpause() external onlyOwner {
        _unpause();
    }
}
