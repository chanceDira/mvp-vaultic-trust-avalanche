import Link from "next/link";
import type { NextPage } from "next";
import { BuildingOffice2Icon, PlusCircleIcon } from "@heroicons/react/24/outline";
import { getMetadata } from "~~/utils/scaffold-eth/getMetadata";

export const metadata = getMetadata({
  title: "Owner",
  description: "Submit and manage your tokenized real-world assets on Vaultic Trust.",
});

const OwnerPage: NextPage = () => {
  return (
    <div className="flex flex-col grow">
      <section className="px-4 py-8 md:py-12">
        <div className="max-w-4xl mx-auto">
          <div className="flex items-center gap-3 mb-2">
            <div className="w-10 h-10 rounded-lg bg-primary/10 flex items-center justify-center">
              <BuildingOffice2Icon className="h-5 w-5 text-primary" />
            </div>
            <h1 className="text-3xl font-bold text-base-content">Owner dashboard</h1>
          </div>
          <p className="text-base-content/80 mb-8">
            Submit real-world assets with documentation. Choose whole-asset sale or fractional tokenization.
          </p>

          <div className="card bg-base-100 border border-base-300 shadow-sm">
            <div className="card-body">
              <h2 className="card-title text-lg">Your assets</h2>
              <p className="text-base-content/70 text-sm">
                Assets you list will appear here with funding status. Connect your wallet to get started.
              </p>
              <div className="flex flex-col sm:flex-row gap-3 mt-4">
                <button className="btn btn-primary gap-2" disabled>
                  <PlusCircleIcon className="h-5 w-5" />
                  List new asset (coming soon)
                </button>
                <Link href="/marketplace" className="btn btn-ghost gap-2">
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

export default OwnerPage;
