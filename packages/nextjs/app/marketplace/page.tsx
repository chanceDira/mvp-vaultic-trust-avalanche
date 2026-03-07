import Link from "next/link";
import type { NextPage } from "next";
import { Squares2X2Icon } from "@heroicons/react/24/outline";
import { getMetadata } from "~~/utils/scaffold-eth/getMetadata";

export const metadata = getMetadata({
  title: "Marketplace",
  description: "Browse tokenized real-world assets and invest on Vaultic Trust.",
});

const MarketplacePage: NextPage = () => {
  return (
    <div className="flex flex-col grow">
      <section className="px-4 py-8 md:py-12">
        <div className="max-w-5xl mx-auto">
          <div className="flex items-center gap-3 mb-2">
            <div className="w-10 h-10 rounded-lg bg-primary/10 flex items-center justify-center">
              <Squares2X2Icon className="h-5 w-5 text-primary" />
            </div>
            <h1 className="text-3xl font-bold text-base-content">Marketplace</h1>
          </div>
          <p className="text-base-content/80 mb-8">
            Browse tokenized assets. Invest in whole assets or buy fractions with on-chain ownership.
          </p>

          <div className="card bg-base-100 border border-base-300 shadow-sm">
            <div className="card-body items-center text-center py-12">
              <Squares2X2Icon className="h-16 w-16 text-base-300" />
              <h2 className="card-title text-lg">No assets yet</h2>
              <p className="text-base-content/70 text-sm max-w-md">
                Tokenized assets will appear here. Asset cards will show name, valuation, location, ownership model, and
                funding progress.
              </p>
              <Link href="/owner" className="btn btn-ghost mt-2">
                List an asset as owner
              </Link>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
};

export default MarketplacePage;
