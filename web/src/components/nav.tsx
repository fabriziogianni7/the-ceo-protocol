"use client";

import Link from "next/link";
import Image from "next/image";
import { usePathname } from "next/navigation";
import { useEffect, useMemo, useRef, useState } from "react";
import { ThemeToggle } from "@/components/theme-toggle";
import { Button } from "@/components/ui/button";
import { useAccount, useChainId, useConnect, useDisconnect, useSwitchChain } from "wagmi";
import { monadMainnet } from "@/lib/web3/chains";

const navItems = [
  { href: "/", label: "Home" },
  { href: "/stats", label: "Performance" },
  { href: "/humans", label: "For Humans" },
  { href: "/agents", label: "For Agents" },
  { href: "/discuss", label: "Discussion" },
];

export function Nav() {
  const pathname = usePathname();
  const { address, chain, isConnected } = useAccount();
  const chainId = useChainId();
  const { connect, connectors, isPending } = useConnect();
  const { disconnect } = useDisconnect();
  const { switchChain, isPending: isSwitchingChain } = useSwitchChain();
  const [isWalletMenuOpen, setIsWalletMenuOpen] = useState(false);
  const walletMenuRef = useRef<HTMLDivElement>(null);
  const primaryConnector = connectors[0];
  const isOnMonad = chainId === monadMainnet.id;
  const walletLabel = useMemo(
    () => (address ? `${address.slice(0, 6)}...${address.slice(-4)}` : "Connect Wallet"),
    [address]
  );

  useEffect(() => {
    if (!isWalletMenuOpen) return;
    const onClickOutside = (event: MouseEvent) => {
      if (!walletMenuRef.current) return;
      if (!walletMenuRef.current.contains(event.target as Node)) {
        setIsWalletMenuOpen(false);
      }
    };
    window.addEventListener("mousedown", onClickOutside);
    return () => window.removeEventListener("mousedown", onClickOutside);
  }, [isWalletMenuOpen]);

  return (
    <header className="sticky top-0 z-50 w-full border-b border-[var(--border)] bg-[var(--background)]/95 backdrop-blur supports-[backdrop-filter]:bg-[var(--background)]/60">
      <div className="container mx-auto flex h-14 items-center justify-between px-4">
        <Link href="/" className="flex items-center gap-2">
          <Image
            src="/logo.png"
            alt="THE CEO"
            width={100}
            height={100}
            className="h-9 w-auto"
          />
        </Link>
        <nav className="flex items-center gap-1">
          {navItems.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className={`rounded-[var(--radius)] px-3 py-2 text-sm font-medium transition-colors ${
                pathname === item.href
                  ? "bg-[var(--primary)] text-[var(--primary-foreground)]"
                  : "text-[var(--muted-foreground)] hover:bg-[var(--muted)] hover:text-[var(--foreground)]"
              }`}
            >
              {item.label}
            </Link>
          ))}
        </nav>
        <div className="flex items-center gap-2">
          {isConnected ? (
            <>
              {!isOnMonad && (
                <Button
                  size="sm"
                  variant="destructive"
                  onClick={() => switchChain({ chainId: monadMainnet.id })}
                  disabled={isSwitchingChain}
                >
                  {isSwitchingChain ? "Switching..." : "Wrong network: switch to Monad"}
                </Button>
              )}
              <div className="relative" ref={walletMenuRef}>
                <button
                  type="button"
                  className="rounded-[var(--radius)] border border-[var(--border)] px-3 py-1.5 text-xs text-[var(--muted-foreground)] font-mono hover:bg-[var(--muted)] transition-colors"
                  onClick={() => setIsWalletMenuOpen((prev) => !prev)}
                >
                  {walletLabel}
                </button>
                <div
                  className={`absolute right-0 top-full mt-2 w-60 rounded-[var(--radius)] border border-[var(--border)] bg-[var(--card)] p-2 shadow-md ${
                    isWalletMenuOpen ? "block" : "hidden"
                  }`}
                >
                  <p className="px-2 py-1 text-xs text-[var(--muted-foreground)] break-all">
                    {address}
                  </p>
                  <p className="px-2 pb-2 text-xs text-[var(--muted-foreground)]">
                    Chain: {chain?.name ?? "Unknown"} ({chainId})
                  </p>
                  {!isOnMonad && (
                    <Button
                      size="sm"
                      className="w-full mb-2"
                      onClick={() => switchChain({ chainId: monadMainnet.id })}
                      disabled={isSwitchingChain}
                    >
                      {isSwitchingChain ? "Switching..." : "Switch to Monad Mainnet"}
                    </Button>
                  )}
                  <Button
                    size="sm"
                    variant="outline"
                    className="w-full mb-2"
                    onClick={() => {
                      if (!primaryConnector) return;
                      connect({ connector: primaryConnector });
                    }}
                    disabled={isPending || !primaryConnector}
                  >
                    Change Account
                  </Button>
                  <Button
                    size="sm"
                    variant="outline"
                    className="w-full"
                    onClick={() => {
                      disconnect();
                      setIsWalletMenuOpen(false);
                    }}
                  >
                    Disconnect
                  </Button>
                </div>
              </div>
            </>
          ) : (
            <Button
              size="sm"
              onClick={() => {
                if (!primaryConnector) return;
                connect({ connector: primaryConnector });
              }}
              disabled={isPending || !primaryConnector}
            >
              Connect
            </Button>
          )}
          <ThemeToggle />
        </div>
      </div>
    </header>
  );
}
