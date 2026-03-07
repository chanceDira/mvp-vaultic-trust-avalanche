"use client";

import Link from "next/link";
import type { NextPage } from "next";
import {
  BuildingOffice2Icon,
  CheckCircleIcon,
  CloudIcon,
  CubeIcon,
  CurrencyDollarIcon,
  MapPinIcon,
  SparklesIcon,
  WalletIcon,
} from "@heroicons/react/24/outline";

const ASSET_PREVIEWS = [
  { label: "Real Estate", value: "RWF 1.2B", icon: BuildingOffice2Icon },
  { label: "Carbon Credits", value: "52,000 tCO2e", icon: SparklesIcon },
  { label: "Treasury Bills", value: "12% APY", icon: CurrencyDollarIcon },
  { label: "Commodities", value: "Gold/Tea", icon: CubeIcon },
  { label: "Infrastructure", value: "Power/Water", icon: CloudIcon },
  { label: "Location Oracles", value: "DePIN", icon: MapPinIcon },
];

const Home: NextPage = () => {
  return (
    <div className="flex flex-col grow">
      <section className="px-4 sm:px-6 lg:px-8 py-12 md:py-16">
        <div className="max-w-7xl mx-auto">
          <div className="grid lg:grid-cols-[1fr,400px] gap-12 lg:gap-16 items-start">
            {/* Left: Hero (reference: first screenshot) */}
            <div className="max-w-xl">
              <h1 className="text-4xl md:text-5xl font-bold text-base-content tracking-tight">
                Tokenize Africa&apos;s Real Economy
              </h1>
              <p className="mt-6 text-base md:text-lg text-base-content/80 leading-relaxed">
                Vaultic Trust is the compliant RWA tokenization layer for Rwanda and Africa. Fractionalize real estate,
                commodities, carbon credits, and infrastructure into programmable, liquid digital assets backed by
                verifiable proofs and on-chain transparency.
              </p>
              <div className="mt-8 flex flex-wrap gap-3">
                <Link href="/owner" className="btn btn-primary gap-2">
                  Get Early Access
                </Link>
                <a
                  href="https://vaultictrust.com"
                  target="_blank"
                  rel="noreferrer"
                  className="btn btn-outline border-base-content/30 text-base-content hover:bg-base-200 gap-2"
                >
                  Read the Litepaper
                </a>
              </div>
              <p className="mt-8 text-sm text-base-content/70">Compliance-first • KYC/AML • Auditable</p>
              <ul className="mt-6 space-y-3">
                {["Regulated On/Off-Ramp", "Proof-of-Asset Oracles", "Escrow & Custody", "Secondary Liquidity"].map(
                  (item, i) => (
                    <li key={i} className="flex items-center gap-2 text-base-content/80">
                      <CheckCircleIcon className="h-5 w-5 text-primary shrink-0" />
                      <span>{item}</span>
                    </li>
                  ),
                )}
              </ul>
            </div>

            {/* Right: Asset Tokenization Preview panel */}
            <div className="bg-base-200/80 rounded-2xl border border-base-300 shadow-sm p-6 lg:p-8">
              <h2 className="text-lg font-semibold text-base-content mb-6">Asset Tokenization Preview</h2>
              <div className="grid grid-cols-2 gap-4 mb-8">
                {ASSET_PREVIEWS.map(({ label, value, icon: Icon }) => (
                  <div key={label} className="bg-base-100 rounded-xl border border-base-300 p-4 flex flex-col gap-1">
                    <Icon className="h-5 w-5 text-primary" />
                    <span className="font-medium text-base-content text-sm">{label}</span>
                    <span className="text-xs text-base-content/70">{value}</span>
                  </div>
                ))}
              </div>
              <div className="pt-4 border-t border-base-300">
                <p className="font-semibold text-base-content">VT-RWA: Kigali Green Tower</p>
                <p className="text-xs text-base-content/70 mt-1">
                  Supply: 1,000,000 VT-KGT • Compliance: ERC-3643 • Oracle: Chainlink PoA • Custody: Qualified Trustee
                </p>
                <div className="mt-3 h-2 rounded-full bg-base-300 overflow-hidden">
                  <div
                    className="h-full rounded-full bg-primary"
                    style={{ width: "65%" }}
                    role="progressbar"
                    aria-valuenow={65}
                    aria-valuemin={0}
                    aria-valuemax={100}
                  />
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* How it works (preserve app structure) */}
      <section id="how-it-works" className="py-12 md:py-16 px-4 sm:px-6 lg:px-8 bg-base-200/50">
        <div className="max-w-5xl mx-auto">
          <h2 className="text-2xl font-semibold text-center text-base-content mb-10">How it works</h2>
          <div className="grid md:grid-cols-3 gap-8">
            <div className="card bg-base-100 border border-base-300 shadow-sm">
              <div className="card-body">
                <div className="w-12 h-12 rounded-lg bg-primary/10 flex items-center justify-center mb-2">
                  <BuildingOffice2Icon className="h-6 w-6 text-primary" />
                </div>
                <h3 className="card-title text-lg">Asset owners</h3>
                <p className="text-base-content/80 text-sm">
                  Submit real-world assets with documentation. Choose whole-asset sale or fractional tokenization.
                </p>
                <Link href="/owner" className="link link-primary text-sm mt-2">
                  Go to Owner dashboard
                </Link>
              </div>
            </div>
            <div className="card bg-base-100 border border-base-300 shadow-sm">
              <div className="card-body">
                <div className="w-12 h-12 rounded-lg bg-primary/10 flex items-center justify-center mb-2">
                  <CubeIcon className="h-6 w-6 text-primary" />
                </div>
                <h3 className="card-title text-lg">Marketplace</h3>
                <p className="text-base-content/80 text-sm">
                  Browse tokenized assets. Invest in whole assets or buy fractions with on-chain ownership.
                </p>
                <Link href="/marketplace" className="link link-primary text-sm mt-2">
                  Browse marketplace
                </Link>
              </div>
            </div>
            <div className="card bg-base-100 border border-base-300 shadow-sm">
              <div className="card-body">
                <div className="w-12 h-12 rounded-lg bg-primary/10 flex items-center justify-center mb-2">
                  <WalletIcon className="h-6 w-6 text-primary" />
                </div>
                <h3 className="card-title text-lg">Investors</h3>
                <p className="text-base-content/80 text-sm">
                  View your portfolio. Track whole-asset and fractional holdings with transparent funding progress.
                </p>
                <Link href="/investor" className="link link-primary text-sm mt-2">
                  View portfolio
                </Link>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className="py-10 px-4 border-t border-base-300">
        <div className="max-w-3xl mx-auto text-center">
          <p className="text-base-content/80">
            Built on <span className="font-medium text-base-content">Avalanche C-Chain</span> for low gas and high
            throughput. On-chain ownership and funding progress.
          </p>
        </div>
      </section>
    </div>
  );
};

export default Home;
