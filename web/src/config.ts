// On-chain addresses. Filled from the deploy output (scripts/setup.ts writes
// these). Falls back to placeholders so the app still builds pre-deploy.
export const NETWORK = (process.env.NEXT_PUBLIC_NETWORK ?? "testnet") as
  | "testnet"
  | "mainnet"
  | "devnet"
  | "localnet";

// Public on-chain IDs from the testnet deploy — baked in as defaults so the
// site builds & runs with zero env config (e.g. on Vercel). Override via env.
export const PACKAGE_ID =
  process.env.NEXT_PUBLIC_PACKAGE_ID ??
  "0xa84fbade273e466646d5d493e781f5a715672c6b9ecc22117d3ee0fefe552b25";
export const BANK_ID =
  process.env.NEXT_PUBLIC_BANK_ID ??
  "0x0ad51c8b6f674e3bccfa7597da5163c0b7d9d67629408e6ec7e9a394ff94b08d";
export const PRICE_FEED_ID =
  process.env.NEXT_PUBLIC_PRICE_FEED_ID ??
  "0xebe6df4e26bacbb632fd580b668ef2f53ca773f18436d12c488199a70efa4a12";
export const WBTC_TREASURY_ID =
  process.env.NEXT_PUBLIC_WBTC_TREASURY_ID ??
  "0x8e9c51acb92cbfb89f5362616177e3816fa7fc4b9bc9a4e70739a65bc201a5bf";
export const USDY_TREASURY_ID =
  process.env.NEXT_PUBLIC_USDY_TREASURY_ID ??
  "0x1216eee8c95c6f526d6c0275cd23e9a6aa57c2546a59ae7680e0763ebfeb5118";
// Admin price-crash control: only shown when this is set (kept empty on the
// public site; set NEXT_PUBLIC_ORACLE_CAP_ID locally for demo recording).
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
