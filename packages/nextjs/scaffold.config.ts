import type { Address } from "viem";
import * as chains from "viem/chains";

/** Proxy + implementation addresses for a contract. */
export type ProxyContractAddresses = {
  proxy: Address;
  implementation: Address;
};

/** Implementation-only (e.g. fractional token implementation). */
export type ImplementationAddress = {
  implementation: Address;
};

/** Single-address contract (e.g. payment token). */
export type SingleContractAddress = {
  address: Address;
};

/** Typed deployed contract addresses per chain. */
export type DeployedContractAddresses = {
  VaulticAssetRegistry: ProxyContractAddresses;
  VaulticInvestmentManager: ProxyContractAddresses;
  VaulticFractionalOwnershipToken: ImplementationAddress;
  MockERC20: SingleContractAddress;
};

/** Contract addresses by chain ID. Proxies are the app endpoints; implementations for verification/upgrades. */
export const deployedContractAddresses: Partial<Record<number, DeployedContractAddresses>> = {
  [chains.avalancheFuji.id]: {
    VaulticAssetRegistry: {
      proxy: "0x89dAc7d94e07609F281138Db9EAA8A2A483A1464",
      implementation: "0x15AD832cF700558e8A0919E36eEA032a477cA6ad",
    },
    VaulticInvestmentManager: {
      proxy: "0x87Ba556D63e1b6FD7C82ba024118249F235934E3",
      implementation: "0xeFeBF5385e7774A9eE144Fe21e3ccd3c06B3C94f",
    },
    VaulticFractionalOwnershipToken: {
      implementation: "0x607b282F23C2e357Bf320EAbE50e0Ea3Aa45274F",
    },
    MockERC20: {
      address: "0x2082E20F621c5Dd9CbEF0288E6A695523c93A941",
    },
  },
  // [chains.avalanche.id]: { ... } — add when mainnet is deployed
};

/**
 * Vaultic Trust – network and wallet configuration.
 */
export type BaseConfig = {
  targetNetworks: readonly chains.Chain[];
  pollingInterval: number;
  alchemyApiKey: string;
  rpcOverrides?: Record<number, string>;
  walletConnectProjectId: string;
  burnerWalletMode: "localNetworksOnly" | "allNetworks" | "disabled";
};

export type ScaffoldConfig = BaseConfig;

export const DEFAULT_ALCHEMY_API_KEY = "cR4WnXePioePZ5fFrnSiR";

// Vaultic Trust: primary chain is Avalanche C-Chain; Fuji testnet and Hardhat for local dev
const scaffoldConfig = {
  targetNetworks: [chains.avalanche, chains.avalancheFuji, chains.hardhat],
  // L2-style chains (Avalanche C-Chain) benefit from faster polling
  pollingInterval: 3000,
  // This is ours Alchemy's default API key.
  // You can get your own at https://dashboard.alchemyapi.io
  // It's recommended to store it in an env variable:
  // .env.local for local testing, and in the Vercel/system env config for live apps.
  alchemyApiKey: process.env.NEXT_PUBLIC_ALCHEMY_API_KEY || DEFAULT_ALCHEMY_API_KEY,
  // If you want to use a different RPC for a specific network, you can add it here.
  // The key is the chain ID, and the value is the HTTP RPC URL
  rpcOverrides: {
    [chains.avalanche.id]: process.env.NEXT_PUBLIC_AVALANCHE_RPC_URL || "https://api.avax.network/ext/bc/C/rpc",
    [chains.avalancheFuji.id]:
      process.env.NEXT_PUBLIC_AVALANCHE_FUJI_RPC_URL || "https://api.avax-test.network/ext/bc/C/rpc",
  },
  // This is ours WalletConnect's default project ID.
  // You can get your own at https://cloud.walletconnect.com
  // It's recommended to store it in an env variable:
  // .env.local for local testing, and in the Vercel/system env config for live apps.
  walletConnectProjectId: process.env.NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID || "3a8170812b534d0ff9d794f19a901d64",
  // Configure Burner Wallet visibility:
  // - "localNetworksOnly": only show when all target networks are local (hardhat/anvil)
  // - "allNetworks": show on any configured target networks
  // - "disabled": completely disable
  burnerWalletMode: "localNetworksOnly",
} as const satisfies ScaffoldConfig;

export default scaffoldConfig;
