// On-chain addresses. Filled from the deploy output (scripts/setup.ts writes
// these). Falls back to placeholders so the app still builds pre-deploy.
export const NETWORK = (process.env.NEXT_PUBLIC_NETWORK ?? "testnet") as
  | "testnet"
  | "mainnet"
  | "devnet"
  | "localnet";

export const PACKAGE_ID = process.env.NEXT_PUBLIC_PACKAGE_ID ?? "0xTODO";
export const BANK_ID = process.env.NEXT_PUBLIC_BANK_ID ?? "0xTODO";
export const PRICE_FEED_ID = process.env.NEXT_PUBLIC_PRICE_FEED_ID ?? "0xTODO";
export const WBTC_TREASURY_ID =
  process.env.NEXT_PUBLIC_WBTC_TREASURY_ID ?? "0xTODO";
export const USDY_TREASURY_ID =
  process.env.NEXT_PUBLIC_USDY_TREASURY_ID ?? "0xTODO";
export const ORACLE_CAP_ID = process.env.NEXT_PUBLIC_ORACLE_CAP_ID ?? "";

export const WBTC_TYPE = `${PACKAGE_ID}::wbtc::WBTC`;
export const USDY_TYPE = `${PACKAGE_ID}::usdy::USDY`;

export const WBTC_DECIMALS = 8; // sats
export const USDY_DECIMALS = 6; // micro-USDY
export const PRICE_DECIMALS = 6; // oracle price scale (USD * 1e6)

export const isConfigured = () =>
  PACKAGE_ID !== "0xTODO" && BANK_ID !== "0xTODO" && PRICE_FEED_ID !== "0xTODO";

export const explorerObject = (id: string) =>
  `https://suiscan.xyz/${NETWORK}/object/${id}`;
export const explorerTx = (digest: string) =>
  `https://suiscan.xyz/${NETWORK}/tx/${digest}`;
