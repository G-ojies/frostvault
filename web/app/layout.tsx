import type { Metadata } from "next";
import "./globals.css";
import "@mysten/dapp-kit/dist/index.css";
import { Providers } from "./providers";

export const metadata: Metadata = {
  title: "FrostVault — Freeze your BTC, borrow on Sui",
  description:
    "Permissionless BTC-collateralized stablecoin borrowing on Sui, with Deepbook-routed liquidations.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
