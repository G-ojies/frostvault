"use client";

import { useSuiClientQuery, useCurrentAccount } from "@mysten/dapp-kit";
import { BANK_ID, PRICE_FEED_ID } from "./config";

export interface BankState {
  reserve: bigint;
  collateral: bigint;
  totalDebt: bigint;
  maxLtvBps: number;
  liqThresholdBps: number;
  liqBonusBps: number;
  positionsTableId?: string;
}

export interface PositionState {
  collateral: bigint; // sats
  debt: bigint; // micro-USDY
}

const big = (v: unknown): bigint => {
  try {
    return BigInt((v as any) ?? 0);
  } catch {
    return 0n;
  }
};

/** Oracle BTC price, scaled 1e6. Polls so the UI reacts to a live price crash. */
export function usePrice() {
  const q = useSuiClientQuery(
    "getObject",
    { id: PRICE_FEED_ID, options: { showContent: true } },
    { refetchInterval: 3000 },
  );
  const fields = (q.data?.data?.content as any)?.fields;
  return { price6: fields ? big(fields.price_6dec) : 0n, query: q };
}

/** Shared Bank: pool balances, risk params, and the positions Table id. */
export function useBank() {
  const q = useSuiClientQuery(
    "getObject",
    { id: BANK_ID, options: { showContent: true } },
    { refetchInterval: 5000 },
  );
  const f = (q.data?.data?.content as any)?.fields;
  const bank: BankState | null = f
    ? {
        reserve: big(f.reserve?.fields?.value ?? f.reserve),
        collateral: big(f.collateral?.fields?.value ?? f.collateral),
        totalDebt: big(f.total_debt),
        maxLtvBps: Number(f.max_ltv_bps ?? 0),
        liqThresholdBps: Number(f.liquidation_threshold_bps ?? 0),
        liqBonusBps: Number(f.liquidation_bonus_bps ?? 0),
        positionsTableId: f.positions?.fields?.id?.id,
      }
    : null;
  return { bank, query: q };
}

/** A given address's position, read straight from the Table dynamic field. */
export function usePosition(owner?: string, tableId?: string) {
  const q = useSuiClientQuery(
    "getDynamicFieldObject",
    { parentId: tableId as string, name: { type: "address", value: owner as string } },
    { enabled: !!owner && !!tableId, refetchInterval: 3000, retry: false },
  );
  const value = (q.data?.data?.content as any)?.fields?.value;
  const pf = value?.fields ?? value;
  const position: PositionState | null = pf
    ? { collateral: big(pf.collateral), debt: big(pf.debt) }
    : null;
  return { position, query: q };
}

/** The connected wallet's balance of a coin type. */
export function useCoinBalance(coinType: string) {
  const acct = useCurrentAccount();
  const q = useSuiClientQuery(
    "getBalance",
    { owner: acct?.address as string, coinType },
    { enabled: !!acct, refetchInterval: 3000 },
  );
  return { total: q.data ? big(q.data.totalBalance) : 0n, query: q };
}

// ===== Client-side risk math (mirrors the Move contract for display) =====

const BPS = 10000n;
const SATS_PER_BTC = 100_000_000n;

export function collateralValue(collateralSats: bigint, price6: bigint): bigint {
  return (collateralSats * price6) / SATS_PER_BTC;
}

export function maxBorrowable(
  collateralSats: bigint,
  price6: bigint,
  maxLtvBps: number,
): bigint {
  return (collateralValue(collateralSats, price6) * BigInt(maxLtvBps)) / BPS;
}

/** Health factor in bps: >=10000 healthy, <10000 liquidatable. */
export function healthFactorBps(
  pos: PositionState,
  price6: bigint,
  liqThresholdBps: number,
): number {
  if (pos.debt === 0n) return 0xffffffff;
  const collVal = collateralValue(pos.collateral, price6);
  return Number((collVal * BigInt(liqThresholdBps)) / pos.debt);
}
