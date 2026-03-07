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
yarn deploy --network avalanche       # Avalanche C-Chain mainnet
```

---

## Deployed contracts

Canonical addresses per network. Proxies are the application’s contract endpoints.

### Avalanche Fuji (chain ID 43113)

| Contract | Role | Address |
|----------|------|---------|
| VaulticAssetRegistry | Proxy | `0x89dAc7d94e07609F281138Db9EAA8A2A483A1464` |
| VaulticAssetRegistry_Implementation | Implementation | `0x15AD832cF700558e8A0919E36eEA032a477cA6ad` |
| VaulticInvestmentManager | Proxy | `0x87Ba556D63e1b6FD7C82ba024118249F235934E3` |
| VaulticInvestmentManager_Implementation | Implementation | `0xeFeBF5385e7774A9eE144Fe21e3ccd3c06B3C94f` |
| VaulticFractionalOwnershipToken | Implementation | `0x607b282F23C2e357Bf320EAbE50e0Ea3Aa45274F` |
| MockERC20 | Payment token | `0x2082E20F621c5Dd9CbEF0288E6A695523c93A941` |

**Why only an implementation for the fractional token?** The fractional token is deployed once as a singleton implementation. The InvestmentManager creates a **new EIP-1167 minimal proxy (clone)** for each asset when you call `tokenizeAsset()`. Those per-asset proxy addresses are not fixed at deploy time; they are stored in the registry and in the investment pool (`tokenContract` per asset).

### Avalanche C-Chain (mainnet)

Deploy with `yarn deploy --network avalanche` and update this section with the new addresses. `deployedContracts.ts` is regenerated on deploy.

---

## Commands

| Command | Description |
|---------|-------------|
| `yarn chain` | Start local Hardhat chain |
| `yarn deploy` | Deploy contracts (default: local; use `--network` for Fuji/mainnet) |
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
