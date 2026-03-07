"use client";

import Link from "next/link";
import type { NextPage } from "next";
import { BuildingOffice2Icon, Squares2X2Icon, WalletIcon } from "@heroicons/react/24/outline";

const Home: NextPage = () => {
  return (
    <>
      <div className="flex flex-col grow">
        {/* Hero */}
        <section className="relative py-16 md:py-24 px-4 overflow-hidden">
          <div className="absolute inset-0 bg-gradient-to-b from-primary/5 via-transparent to-transparent pointer-events-none" />
          <div className="max-w-4xl mx-auto text-center relative">
            <h1 className="text-4xl md:text-5xl lg:text-6xl font-bold text-base-content tracking-tight">
              Tokenize Africa&apos;s
              <br />
              <span className="text-primary">Real Economy</span>
            </h1>
            <p className="mt-6 text-lg md:text-xl text-base-content/80 max-w-2xl mx-auto leading-relaxed">
              Vaultic Trust is the compliant RWA tokenization layer for Rwanda and Africa. Fractionalize real estate,
              commodities, carbon credits, and infrastructure into programmable, liquid digital assets.
            </p>
            <div className="mt-10 flex flex-col sm:flex-row gap-4 justify-center">
              <Link href="/owner" className="btn btn-primary btn-lg gap-2">
                <BuildingOffice2Icon className="h-5 w-5" />
                List your asset
              </Link>
              <Link
                href="/marketplace"
                className="btn btn-outline btn-lg border-primary text-primary hover:bg-primary hover:text-primary-content gap-2"
              >
                <Squares2X2Icon className="h-5 w-5" />
                Browse marketplace
              </Link>
            </div>
          </div>
        </section>

        {/* Value props */}
        <section className="py-12 md:py-16 px-4 bg-base-200/50">
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
                    Go to Owner dashboard →
                  </Link>
                </div>
              </div>
              <div className="card bg-base-100 border border-base-300 shadow-sm">
                <div className="card-body">
                  <div className="w-12 h-12 rounded-lg bg-primary/10 flex items-center justify-center mb-2">
                    <Squares2X2Icon className="h-6 w-6 text-primary" />
                  </div>
                  <h3 className="card-title text-lg">Marketplace</h3>
                  <p className="text-base-content/80 text-sm">
                    Browse tokenized assets. Invest in whole assets or buy fractions with on-chain ownership.
                  </p>
                  <Link href="/marketplace" className="link link-primary text-sm mt-2">
                    Browse marketplace →
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
                    View portfolio →
                  </Link>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* CTA strip */}
        <section className="py-12 px-4 border-t border-base-300">
          <div className="max-w-3xl mx-auto text-center">
            <p className="text-base-content/80">
              Built on <span className="font-medium text-base-content">Avalanche C-Chain</span> for low gas and high
              throughput. On-chain ownership and funding progress.
            </p>
          </div>
        </section>
      </div>
    </>
  );
};

export default Home;
