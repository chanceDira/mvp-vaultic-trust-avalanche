"use client";

import Link from "next/link";
import { useAccount } from "wagmi";
import { BuildingOffice2Icon } from "@heroicons/react/24/outline";
import { AssetCard } from "~~/components/assets/AssetCard";
import { AssetForm } from "~~/components/assets/AssetForm";
import { useScaffoldReadContract } from "~~/hooks/scaffold-eth";

export default function OwnerPage() {
  const { address } = useAccount();
  const { data: assetIds, isLoading: isLoadingIds } = useScaffoldReadContract({
    contractName: "VaulticAssetRegistry",
    functionName: "getAssetsByOwner",
    args: address ? [address] : undefined,
  });

  const ids = (assetIds as bigint[] | undefined) ?? [];

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

          <div className="mb-8">
            <AssetForm />
          </div>

          <h2 className="text-xl font-bold text-base-content mb-4">Your assets</h2>
          {!address ? (
            <div className="rounded-xl border border-base-300 bg-base-100 p-8 text-center text-base-content/70">
              Connect your wallet to see your assets and register new ones.
            </div>
          ) : isLoadingIds ? (
            <div className="rounded-xl border border-base-300 bg-base-100 p-8 text-center">
              <span className="loading loading-spinner loading-md" />
            </div>
          ) : ids.length === 0 ? (
            <div className="rounded-xl border border-base-300 bg-base-100 p-8 text-center text-base-content/70">
              No assets yet. Register an asset above or{" "}
              <Link href="/marketplace" className="link link-primary">
                browse the marketplace
              </Link>
              .
            </div>
          ) : (
            <div className="space-y-4">
              {ids.map(id => (
                <AssetCard key={id.toString()} assetId={id} showInvestmentPanel={false} />
              ))}
            </div>
          )}
        </div>
      </section>
    </div>
  );
}
