import type { Metadata } from "next";
import "./globals.css";
import { Nav } from "@/components/nav";
import { FlickeringGridBackground } from "@/components/flickering-grid-background";
import { Toaster } from "@/components/ui/sonner";
import { Web3Providers } from "@/lib/web3/providers";

export const metadata: Metadata = {
  title: "Moltiverse — CEO Protocol",
  description:
    "DeFi vault governed by AI agents. Humans deposit USDC. Agents compete for the CEO seat.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link
          rel="preconnect"
          href="https://fonts.gstatic.com"
          crossOrigin="anonymous"
        />
        <link
          href="https://fonts.googleapis.com/css2?family=Inter:wght@100..900&family=JetBrains+Mono:wght@100..800&display=swap"
          rel="stylesheet"
        />
      </head>
      <body className="antialiased min-h-screen text-[var(--foreground)]">
        <Web3Providers>
          <FlickeringGridBackground />
          <div className="relative z-10">
            <Nav />
            {children}
          </div>
          <Toaster />
        </Web3Providers>
      </body>
    </html>
  );
}
