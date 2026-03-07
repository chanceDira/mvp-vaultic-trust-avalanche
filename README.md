# Vaultic Trust

**Tokenize Africa's real economy.** Compliant RWA tokenization for Rwanda and Africa. Fractionalize real estate, commodities, carbon credits, and infrastructure into programmable, liquid digital assets on Avalanche.

Built with [Scaffold-ETH 2](https://docs.scaffoldeth.io): Next.js, RainbowKit, Hardhat, Wagmi, Viem, TypeScript.

---

## What it does

- **Asset owners**: Submit real-world assets, choose whole-asset sale or fractional tokenization.
- **Investors**: Browse the marketplace, invest in whole assets or buy fractions; ownership is on-chain.
- **Stack**: Next.js (App Router), TailwindCSS, DaisyUI, Solidity on **Avalanche C-Chain** (and Fuji testnet).

See [CLAUDE.md](CLAUDE.md), [AGENTS.md](AGENTS.md), [SYSTEM_ARCHITECTURE.md](SYSTEM_ARCHITECTURE.md), and [SMART_CONTRACTS.md](SMART_CONTRACTS.md) for product and contract details.

---

## Requirements

- [Node (>= v20.18.3)](https://nodejs.org/en/download/)
- [Yarn](https://classic.yarnpkg.com/en/docs/install/) (v1 or v2+)
- [Git](https://git-scm.com/downloads)

---

## Install

From the repo root (Yarn workspaces):

```bash
yarn install
```

If you see a cache error, refresh and reinstall:

```bash
yarn install:refresh
```

---

## Quick start

1. **Local chain** (terminal 1):

   ```bash
   yarn chain
   ```

2. **Deploy contracts** (terminal 2, after chain is up):

   ```bash
   yarn deploy
   ```

   For Avalanche Fuji testnet:

   ```bash
   yarn deploy --network avalancheFuji
   ```

   For Avalanche C-Chain mainnet:

   ```bash
   yarn deploy --network avalanche
   ```

3. **Frontend** (terminal 3):

   ```bash
   yarn start
   ```

   Open [http://localhost:3000](http://localhost:3000). Connect your wallet (Avalanche/Fuji or local).

---

## Deployed contracts

Addresses are also written to `packages/nextjs/contracts/deployedContracts.ts` by the deploy script. The app reads from that file.

### Avalanche Fuji (testnet, chain ID 43113)

| Contract | Role | Address |
|----------|------|---------|
| **VaulticAssetRegistry** | Proxy (use this in the app) | `0x89dAc7d94e07609F281138Db9EAA8A2A483A1464` |
| VaulticAssetRegistry_Implementation | Implementation | `0x15AD832cF700558e8A0919E36eEA032a477cA6ad` |
| **VaulticInvestmentManager** | Proxy (use this in the app) | `0x87Ba556D63e1b6FD7C82ba024118249F235934E3` |
| VaulticInvestmentManager_Implementation | Implementation | `0xeFeBF5385e7774A9eE144Fe21e3ccd3c06B3C94f` |
| VaulticFractionalOwnershipToken | Implementation (template) | `0x607b282F23C2e357Bf320EAbE50e0Ea3Aa45274F` |
| MockERC20 | Test token | `0x2082E20F621c5Dd9CbEF0288E6A695523c93A941` |

Use the **proxy** addresses for `VaulticAssetRegistry` and `VaulticInvestmentManager` in the UI and integrations. Implementation addresses are for upgradeability and verification.

### Avalanche C-Chain (mainnet)

Deploy with `yarn deploy --network avalanche` when ready. Then update this table and `deployedContracts.ts` will be regenerated.

---

## Commands

| Command | Description |
|---------|-------------|
| `yarn chain` | Start local Hardhat chain |
| `yarn deploy` | Deploy contracts (default: local). Use `--network avalancheFuji` or `--network avalanche` for testnet/mainnet |
| `yarn start` | Run Next.js app at http://localhost:3000 |
| `yarn compile` | Compile Solidity contracts |
| `yarn hardhat:test` | Run contract tests |
| `yarn lint` | Lint packages |
| `yarn format` | Format code |

---

## Project layout

- `packages/hardhat/` – Solidity contracts, deploy scripts, tests
- `packages/nextjs/` – Next.js app (App Router), UI, `contracts/deployedContracts.ts` (generated)
- `AGENTS.md`, `CLAUDE.md`, `SYSTEM_ARCHITECTURE.md`, `SMART_CONTRACTS.md` – product and contract docs

---

## Configuration

- **Networks**: `packages/nextjs/scaffold.config.ts` (target networks, RPC overrides).
- **Contract addresses**: Generated into `packages/nextjs/contracts/deployedContracts.ts` on deploy; do not edit by hand.
- **Hardhat networks**: `packages/hardhat/hardhat.config.ts` (e.g. `avalanche`, `avalancheFuji`).

---

## License

See repository license. Vaultic Trust – tokenizing Africa's real economy with trust, transparency, and traceability.
