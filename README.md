# Vaultic Trust

**Tokenize Africa's real economy.** Compliant RWA tokenization for Rwanda and Africa. Fractionalize real estate, commodities, carbon credits, and infrastructure into programmable, liquid digital assets on Avalanche.

Built with Next.js, RainbowKit, Hardhat, Wagmi, Viem, and TypeScript.

---

## Product

- **Asset owners**: Submit real-world assets; choose whole-asset sale or fractional tokenization.
- **Investors**: Browse the marketplace and invest in whole assets or fractions; ownership is on-chain.
- **Stack**: Next.js (App Router), TailwindCSS, DaisyUI, Solidity on **Avalanche C-Chain** and Fuji testnet.

---

## Requirements

- Node (>= v20.18.3)
- Yarn (v1 or v2+)
- Git

---

## Install

From the repository root:

```bash
yarn install
```

To refresh cache and reinstall:

```bash
yarn install:refresh
```

---

## Running the application

**Development**

```bash
yarn chain      # terminal 1: local chain
yarn deploy     # terminal 2: deploy contracts
yarn start      # terminal 3: Next.js at http://localhost:3000
```

**Production**

- Deploy contracts to the target network (e.g. Avalanche or Fuji), then build and serve the Next.js app.
- Contract addresses are written to `packages/nextjs/contracts/deployedContracts.ts` by the deploy step.

**Deploy contracts**

```bash
yarn deploy --network avalancheFuji   # Fuji testnet
yarn deploy --network avalanche      # Avalanche C-Chain mainnet
```

**Payment token**

- **Avalanche Fuji:** The app uses **Fuji USDC testnet** only (`0x5425890298aed601595a70AB815c96711a31Bc65`). No mock token is deployed on Fuji; the Investment Manager is deployed with this address. The frontend reads `paymentToken()` from the contract, so the buy flow approves and spends Fuji USDC.
- **Local (Hardhat):** A test ERC20 is deployed as "PaymentToken" (same interface as USDC, 6 decimals) so you can run the app locally. No MockERC20.
- **Mainnet:** Set `PAYMENT_TOKEN_ADDRESS` to mainnet USDC (e.g. `0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E`) and run `yarn deploy --network avalanche`.

---

## Deployed contracts

Canonical addresses per network. Proxies are the application’s contract endpoints.

### Avalanche Fuji (chain ID 43113)

| Contract | Role | Address |
|----------|------|---------|
| VaulticAssetRegistry | Proxy | `0x7bE0137284bE5E40Af3e6b5c178C1492F62bF635` |
| VaulticAssetRegistry_Implementation | Implementation | `0x71c116D7bd6965A6912892978B42Fa1c658af9e6` |
| VaulticInvestmentManager | Proxy | `0xcA3EDAfd3344f57e7180ABD051e1bF027498e503` |
| VaulticInvestmentManager_Implementation | Implementation | `0x2c6E61EfB9EdbCF2F5fFdAC52F65F8Dec0bD98dd` |
| VaulticFractionalOwnershipToken | Implementation | `0x4d8f5709AcD40aC1DB92A32F68DB81a1d5B1C3B9` |
| Payment token (Fuji USDC) | Used by Investment Manager | `0x5425890298aed601595a70AB815c96711a31Bc65` |

**Why only an implementation for the fractional token?** The fractional token is deployed once as a singleton implementation. The InvestmentManager creates a **new EIP-1167 minimal proxy (clone)** for each asset when you call `tokenizeAsset()`. Those per-asset proxy addresses are not fixed at deploy time; they are stored in the registry and in the investment pool (`tokenContract` per asset).

**Relist reverts with "execution reverted"?** The registry’s `relistWholeAsset` / `relistAssetAsFractional` are callable only by the address set as **tokenizer**. The deploy script sets the registry’s tokenizer to the Investment Manager **proxy** after deploy. If you redeployed only the Investment Manager (e.g. a new proxy on Fuji) and did not re-run the full deploy, the registry may still point to an old address. Fix: as the **registry owner**, call `VaulticAssetRegistry.setTokenizer(VaulticInvestmentManagerProxyAddress)` with the current IM proxy (e.g. `0xcA3EDAfd3344f57e7180ABD051e1bF027498e503` on Fuji). Verify with `registry.tokenizer()` on-chain.

### Avalanche C-Chain (mainnet)

Deploy with `yarn deploy --network avalanche` and update this section with the new addresses. `deployedContracts.ts` is regenerated on deploy.

---

## Commands

| Command | Description |
|---------|-------------|
| `yarn chain` | Start local Hardhat chain |
| `yarn deploy` | Deploy contracts (default: local; use `--network` for Fuji/mainnet) |
| `yarn deploy:registry` | Deploy/upgrade only VaulticAssetRegistry (e.g. `--network avalancheFuji`) |
| `yarn deploy:investment-manager` | Deploy/upgrade only VaulticInvestmentManager |
| `yarn start` | Run Next.js dev server |
| `yarn next:build` | Build Next.js for production |
| `yarn compile` | Compile Solidity contracts |
| `yarn hardhat:test` | Run contract tests |
| `yarn lint` | Lint packages |
| `yarn format` | Format code |

---

## Project layout

- `packages/hardhat/` – Solidity contracts, deploy scripts, tests
- `packages/nextjs/` – Next.js app (App Router), UI, generated contract data
---

## Configuration

- **Networks and RPC**: `packages/nextjs/scaffold.config.ts`
- **Contract addresses**: `packages/nextjs/contracts/deployedContracts.ts` (generated on deploy)
- **Hardhat networks**: `packages/hardhat/hardhat.config.ts`

---

Vaultic Trust – tokenizing Africa's real economy with trust, transparency, and traceability.
