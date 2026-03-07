import React from "react";
import Link from "next/link";
import { useFetchNativeCurrencyPrice } from "@scaffold-ui/hooks";
import { hardhat } from "viem/chains";
import { CurrencyDollarIcon, MagnifyingGlassIcon } from "@heroicons/react/24/outline";
import { SwitchTheme } from "~~/components/SwitchTheme";
import { Faucet } from "~~/components/scaffold-eth";
import { useTargetNetwork } from "~~/hooks/scaffold-eth/useTargetNetwork";

export const Footer = () => {
  const { targetNetwork } = useTargetNetwork();
  const isLocalNetwork = targetNetwork.id === hardhat.id;
  const { price: nativeCurrencyPrice } = useFetchNativeCurrencyPrice();

  return (
    <footer className="footer footer-center md:footer-horizontal p-4 md:px-6 md:py-3 bg-base-200 text-base-content border-t border-base-300 text-sm">
      <aside className="flex flex-col sm:flex-row items-center gap-1 sm:gap-3 md:place-self-start md:justify-self-start">
        <p className="font-semibold text-primary">Vaultic Trust</p>
        <span className="hidden sm:inline text-base-content/50">·</span>
        <p className="text-base-content/70 max-w-[280px] text-center sm:text-left">
          Tokenizing Africa&apos;s real economy with trust, transparency, and traceability. Built on Avalanche.
        </p>
      </aside>
      <nav className="md:place-self-center">
        <div className="flex flex-wrap justify-center gap-x-4 gap-y-0">
          <Link href="/marketplace" className="link link-hover">
            Marketplace
          </Link>
          <Link href="/owner" className="link link-hover">
            For asset owners
          </Link>
          <Link href="/investor" className="link link-hover">
            For investors
          </Link>
        </div>
      </nav>
      <div className="flex flex-wrap items-center justify-center gap-2 md:place-self-end md:justify-self-end">
        {nativeCurrencyPrice > 0 && (
          <div className="btn btn-primary btn-sm font-normal gap-1 cursor-auto min-h-8">
            <CurrencyDollarIcon className="h-3.5 w-3.5" />
            <span>{nativeCurrencyPrice.toFixed(2)}</span>
          </div>
        )}
        {isLocalNetwork && (
          <>
            <Faucet />
            <Link href="/blockexplorer" passHref className="btn btn-primary btn-sm font-normal gap-1 min-h-8">
              <MagnifyingGlassIcon className="h-3.5 w-3.5" />
              <span>Block Explorer</span>
            </Link>
          </>
        )}
        <SwitchTheme className="flex items-center" />
      </div>
    </footer>
  );
};
