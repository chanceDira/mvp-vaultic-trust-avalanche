"use client";

import { useState } from "react";
import { useAccount } from "wagmi";
import { useDeployedContractInfo, useScaffoldWriteContract } from "~~/hooks/scaffold-eth";
import { notification } from "~~/utils/scaffold-eth";

type InvestmentPanelProps = {
  assetId: bigint;
  pricePerShare: bigint;
  assetName: string;
};

export function InvestmentPanel({ assetId, pricePerShare, assetName }: InvestmentPanelProps) {
  const { address } = useAccount();
  const [shareAmount, setShareAmount] = useState("");
  const { data: investmentManagerInfo } = useDeployedContractInfo({
    contractName: "VaulticInvestmentManager",
  });

  const { writeContractAsync: writeApprove } = useScaffoldWriteContract({
    contractName: "MockERC20",
  });
  const { writeContractAsync: writePurchase, isMining } = useScaffoldWriteContract({
    contractName: "VaulticInvestmentManager",
  });

  const shareNum = shareAmount ? Math.max(0, Math.floor(Number(shareAmount))) : 0;
  const shareAmountBigInt = BigInt(shareNum);
  const paymentAmount = shareAmountBigInt * pricePerShare;

  const handlePurchase = async () => {
    if (!address || !investmentManagerInfo?.address) {
      notification.error("Connect your wallet");
      return;
    }
    if (shareAmountBigInt <= 0n) {
      notification.error("Enter a share amount");
      return;
    }

    try {
      if (paymentAmount > 0n) {
        await writeApprove({
          functionName: "approve",
          args: [investmentManagerInfo.address as `0x${string}`, paymentAmount],
        });
      }
      await writePurchase({
        functionName: "purchaseShares",
        args: [assetId, shareAmountBigInt, paymentAmount],
      });
      notification.success("Shares purchased");
      setShareAmount("");
    } catch (e: unknown) {
      console.error(e);
      notification.error("Purchase failed");
    }
  };

  const pricePerShareFormatted = pricePerShare > 0n ? (Number(pricePerShare) / 1e6).toFixed(2) : "0";

  return (
    <div className="rounded-lg bg-base-200/60 p-4">
      <h4 className="font-semibold text-base-content">Buy shares</h4>
      <p className="mt-1 text-sm text-base-content/70">
        {assetName} · ${pricePerShareFormatted} per share
      </p>
      <div className="mt-3 flex flex-wrap items-end gap-3">
        <div className="flex-1 min-w-[120px]">
          <label className="text-xs font-medium text-base-content/70">Shares</label>
          <input
            type="number"
            min="1"
            value={shareAmount}
            onChange={e => setShareAmount(e.target.value)}
            placeholder="0"
            disabled={!address}
            className="input input-bordered input-sm w-full mt-1"
          />
        </div>
        <button
          type="button"
          className="btn btn-primary btn-sm"
          disabled={!address || shareAmountBigInt <= 0n || isMining}
          onClick={handlePurchase}
        >
          {isMining ? "Confirming..." : "Buy"}
        </button>
      </div>
      {shareAmountBigInt > 0n && (
        <p className="mt-2 text-xs text-base-content/60">
          Total: ${((Number(pricePerShare) * Number(shareAmountBigInt)) / 1e6).toFixed(2)} (payment token)
        </p>
      )}
    </div>
  );
}
