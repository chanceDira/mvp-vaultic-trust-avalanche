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
    <footer className="footer footer-center md:footer-horizontal p-6 md:p-8 bg-base-200 text-base-content border-t border-base-300">
      <aside className="grid-flow-col items-center gap-4 md:place-self-start md:justify-self-start">
        <p className="font-semibold text-primary">Vaultic Trust</p>
        <p className="text-sm opacity-80 max-w-xs">
          Tokenizing Africa&apos;s real economy with trust, transparency, and traceability.
        </p>
      </aside>
      <nav className="grid-flow-col gap-4 md:place-self-center">
        <div className="flex flex-wrap justify-center gap-x-6 gap-y-1 text-sm">
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
      <div className="grid-flow-col gap-4 md:place-self-end md:justify-self-end items-center">
        {nativeCurrencyPrice > 0 && (
          <div className="btn btn-primary btn-sm font-normal gap-1 cursor-auto">
            <CurrencyDollarIcon className="h-4 w-4" />
            <span>{nativeCurrencyPrice.toFixed(2)}</span>
          </div>
        )}
        {isLocalNetwork && (
          <>
            <Faucet />
            <Link href="/blockexplorer" passHref className="btn btn-primary btn-sm font-normal gap-1">
              <MagnifyingGlassIcon className="h-4 w-4" />
              <span>Block Explorer</span>
            </Link>
          </>
        )}
        <SwitchTheme className="flex items-center" />
      </div>
    </footer>
  );
};
