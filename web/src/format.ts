import { WBTC_DECIMALS, USDY_DECIMALS, PRICE_DECIMALS } from "./config";

// Convert a human amount (string/number) to base units (bigint).
export function toBaseUnits(amount: string | number, decimals: number): bigint {
  const s = String(amount).trim();
  if (!s || isNaN(Number(s))) return 0n;
  const [whole, frac = ""] = s.split(".");
  const fracPadded = (frac + "0".repeat(decimals)).slice(0, decimals);
  return BigInt(whole || "0") * 10n ** BigInt(decimals) + BigInt(fracPadded || "0");
}

// Format base units (bigint) to a human string with up to `maxFrac` decimals.
export function fromBaseUnits(
  units: bigint | number,
  decimals: number,
  maxFrac = decimals,
): string {
  const u = BigInt(units);
  const base = 10n ** BigInt(decimals);
  const whole = u / base;
  const frac = u % base;
  let fracStr = frac.toString().padStart(decimals, "0").slice(0, maxFrac);
  fracStr = fracStr.replace(/0+$/, "");
  const wholeStr = whole.toLocaleString("en-US");
  return fracStr ? `${wholeStr}.${fracStr}` : wholeStr;
}

export const fmtBtc = (sats: bigint | number) =>
  fromBaseUnits(sats, WBTC_DECIMALS, 6);
export const fmtUsd = (micro: bigint | number) =>
  fromBaseUnits(micro, USDY_DECIMALS, 2);
export const fmtPrice = (p: bigint | number) =>
  fromBaseUnits(p, PRICE_DECIMALS, 2);

// Health factor: contract returns bps (10000 = at-threshold). Show as ratio.
export function healthLabel(hfBps: number): {
  ratio: string;
  tone: "safe" | "warn" | "danger";
} {
  if (hfBps >= 0xffffffff) return { ratio: "∞", tone: "safe" };
  const ratio = hfBps / 10000;
  const tone = ratio >= 1.5 ? "safe" : ratio >= 1.05 ? "warn" : "danger";
  return { ratio: ratio.toFixed(2) + "x", tone };
}

export const shortAddr = (a?: string) =>
  a ? `${a.slice(0, 6)}…${a.slice(-4)}` : "";
