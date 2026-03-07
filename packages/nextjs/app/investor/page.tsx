import Link from "next/link";
import type { NextPage } from "next";
import { WalletIcon } from "@heroicons/react/24/outline";
import { getMetadata } from "~~/utils/scaffold-eth/getMetadata";

export const metadata = getMetadata({
  title: "Investor",
  description: "View your portfolio and tokenized asset holdings on Vaultic Trust.",
});

const InvestorPage: NextPage = () => {
  return (
    <div className="flex flex-col grow">
      <section className="px-4 py-8 md:py-12">
        <div className="max-w-4xl mx-auto">
          <div className="flex items-center gap-3 mb-2">
            <div className="w-10 h-10 rounded-lg bg-primary/10 flex items-center justify-center">
              <WalletIcon className="h-5 w-5 text-primary" />
            </div>
            <h1 className="text-3xl font-bold text-base-content">Investor portfolio</h1>
          </div>
          <p className="text-base-content/80 mb-8">
            View your whole-asset and fractional token holdings. Funding progress is shown per asset.
          </p>

          <div className="card bg-base-100 border border-base-300 shadow-sm">
            <div className="card-body">
              <h2 className="card-title text-lg">Your holdings</h2>
              <p className="text-base-content/70 text-sm">
                Connect your wallet to see your tokenized asset positions and funding progress.
              </p>
              <div className="mt-4">
                <Link href="/marketplace" className="btn btn-primary gap-2">
                  Browse marketplace
                </Link>
              </div>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
};

export default InvestorPage;
