"use client";

import { useState } from "react";
import {
  ConnectButton,
  useCurrentAccount,
  useSignAndExecuteTransaction,
} from "@mysten/dapp-kit";
import type { Transaction } from "@mysten/sui/transactions";
import {
  WBTC_TYPE,
  USDY_TYPE,
  WBTC_DECIMALS,
  USDY_DECIMALS,
  ORACLE_CAP_ID,
  isConfigured,
  explorerTx,
} from "@/src/config";
import {
  useBank,
  usePrice,
  usePosition,
  useCoinBalance,
  collateralValue,
  maxBorrowable,
  healthFactorBps,
} from "@/src/hooks";
import {
  faucetWbtcTx,
  faucetUsdyTx,
  depositTx,
  borrowTx,
  repayTx,
  withdrawTx,
  liquidateTx,
  setPriceTx,
} from "@/src/tx";
import {
  toBaseUnits,
  fmtBtc,
  fmtUsd,
  fmtPrice,
  healthLabel,
  shortAddr,
} from "@/src/format";

export function Dashboard() {
  const account = useCurrentAccount();
  const { mutate: signAndExecute, isPending } = useSignAndExecuteTransaction();
  const { bank } = useBank();
  const { price6 } = usePrice();
  const { position } = usePosition(account?.address, bank?.positionsTableId);
  const { total: wbtcBal } = useCoinBalance(WBTC_TYPE);
  const { total: usdyBal } = useCoinBalance(USDY_TYPE);

  const [status, setStatus] = useState<{ msg: string; tone: "ok" | "err" } | null>(
    null,
  );

  const run = (tx: Transaction, label: string) => {
    setStatus({ msg: `${label}…`, tone: "ok" });
    signAndExecute(
      { transaction: tx },
      {
        onSuccess: (r) => setStatus({ msg: `${label} ✓ ${r.digest.slice(0, 8)}…`, tone: "ok" }),
        onError: (e) => setStatus({ msg: `${label} failed: ${e.message}`, tone: "err" }),
      },
    );
  };

  if (!isConfigured()) {
    return (
      <div className="frost-card mx-auto mt-10 max-w-xl p-6 text-sm text-slate-300">
        <p className="mb-2 font-semibold text-frost-ice">Not deployed yet</p>
        <p>
          Publish the Move package and copy the IDs into{" "}
          <code className="text-frost-ice">web/.env.local</code> (see{" "}
          <code>.env.local.example</code>). Then restart the dev server.
        </p>
      </div>
    );
  }

  const coll = position?.collateral ?? 0n;
  const debt = position?.debt ?? 0n;
  const collVal = collateralValue(coll, price6);
  const maxBorrow = bank ? maxBorrowable(coll, price6, bank.maxLtvBps) : 0n;
  const available = maxBorrow > debt ? maxBorrow - debt : 0n;
  const hfBps = bank ? healthFactorBps({ collateral: coll, debt }, price6, bank.liqThresholdBps) : 0;
  const hf = healthLabel(hfBps);
  const barPct = Math.max(4, Math.min(100, (hfBps / 10000 / 2) * 100));

  return (
    <div className="mx-auto max-w-3xl px-4 pb-24">
      {/* Top bar */}
      <div className="flex items-center justify-between py-5">
        <div className="flex items-center gap-2 text-lg font-bold">
          <span>❄️</span> FrostVault
        </div>
        <ConnectButton />
      </div>

      {/* Price + pool stats */}
      <div className="frost-card mb-4 flex flex-wrap items-center justify-between gap-4 p-4 text-sm">
        <Stat label="BTC price" value={`$${fmtPrice(price6)}`} />
        <Stat label="Pool reserve" value={`${fmtUsd(bank?.reserve ?? 0n)} USDY`} />
        <Stat label="Total borrowed" value={`${fmtUsd(bank?.totalDebt ?? 0n)} USDY`} />
        <Stat label="Max LTV" value={`${(bank?.maxLtvBps ?? 0) / 100}%`} />
      </div>

      {!account ? (
        <div className="frost-card p-8 text-center text-slate-300">
          Connect a wallet to deposit BTC and borrow.
        </div>
      ) : (
        <>
          {/* Faucet + balances */}
          <div className="frost-card mb-4 p-4">
            <div className="mb-3 flex items-center justify-between">
              <span className="text-sm text-slate-400">
                Wallet · {shortAddr(account.address)}
              </span>
              <div className="flex gap-2">
                <button className="frost-btn-ghost" onClick={() => run(faucetWbtcTx(), "Faucet wBTC")}>
                  + wBTC
                </button>
                <button className="frost-btn-ghost" onClick={() => run(faucetUsdyTx(), "Faucet USDY")}>
                  + USDY
                </button>
              </div>
            </div>
            <div className="flex gap-6 text-sm">
              <Stat label="wBTC" value={fmtBtc(wbtcBal)} />
              <Stat label="USDY" value={fmtUsd(usdyBal)} />
            </div>
          </div>

          {/* Position + health */}
          <div className="frost-card mb-4 p-5">
            <div className="mb-4 flex flex-wrap justify-between gap-4 text-sm">
              <Stat label="Collateral" value={`${fmtBtc(coll)} wBTC`} />
              <Stat label="Collateral value" value={`$${fmtUsd(collVal)}`} />
              <Stat label="Debt" value={`${fmtUsd(debt)} USDY`} />
              <Stat label="Borrowable" value={`${fmtUsd(available)} USDY`} />
            </div>
            <div className="mb-1 flex justify-between text-xs text-slate-400">
              <span>Health factor</span>
              <span
                className={
                  hf.tone === "safe"
                    ? "text-emerald-400"
                    : hf.tone === "warn"
                      ? "text-amber-400"
                      : "text-red-400"
                }
              >
                {hf.ratio} {hf.tone === "danger" && debt > 0n ? "· LIQUIDATABLE" : ""}
              </span>
            </div>
            <div className="h-2 w-full overflow-hidden rounded-full bg-frost-line">
              <div
                className={
                  "h-full rounded-full " +
                  (hf.tone === "safe"
                    ? "bg-emerald-400"
                    : hf.tone === "warn"
                      ? "bg-amber-400"
                      : "bg-red-400")
                }
                style={{ width: `${barPct}%` }}
              />
            </div>
          </div>

          {/* Actions */}
          <div className="grid gap-4 sm:grid-cols-2">
            <ActionForm
              title="Deposit collateral"
              cta="Deposit wBTC"
              suffix="wBTC"
              disabled={isPending}
              onSubmit={(v) => run(depositTx(toBaseUnits(v, WBTC_DECIMALS)), "Deposit")}
            />
            <ActionForm
              title="Borrow"
              cta="Borrow USDY"
              suffix="USDY"
              disabled={isPending}
              onSubmit={(v) => run(borrowTx(toBaseUnits(v, USDY_DECIMALS), account.address), "Borrow")}
            />
            <ActionForm
              title="Repay"
              cta="Repay USDY"
              suffix="USDY"
              disabled={isPending}
              onSubmit={(v) => run(repayTx(toBaseUnits(v, USDY_DECIMALS)), "Repay")}
            />
            <ActionForm
              title="Withdraw collateral"
              cta="Withdraw wBTC"
              suffix="wBTC"
              disabled={isPending}
              onSubmit={(v) => run(withdrawTx(toBaseUnits(v, WBTC_DECIMALS), account.address), "Withdraw")}
            />
          </div>

          {/* Liquidation */}
          <LiquidatePanel
            disabled={isPending}
            onSubmit={(owner, amt) =>
              run(liquidateTx(owner, toBaseUnits(amt, USDY_DECIMALS), account.address), "Liquidate")
            }
          />

          {/* Admin demo control */}
          {ORACLE_CAP_ID && (
            <div className="frost-card mt-4 p-4">
              <p className="mb-2 text-sm text-slate-400">Demo control (admin oracle)</p>
              <div className="flex gap-2">
                <button className="frost-btn-ghost" onClick={() => run(setPriceTx(70_000_000000n), "Crash → $70k")}>
                  Crash BTC → $70k
                </button>
                <button className="frost-btn-ghost" onClick={() => run(setPriceTx(100_000_000000n), "Reset → $100k")}>
                  Reset → $100k
                </button>
              </div>
            </div>
          )}
        </>
      )}

      {status && (
        <div
          className={
            "fixed bottom-4 left-1/2 -translate-x-1/2 rounded-lg px-4 py-2 text-sm " +
            (status.tone === "ok" ? "bg-sky-900 text-sky-100" : "bg-red-900 text-red-100")
          }
        >
          {status.msg}
        </div>
      )}
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <div className="text-xs uppercase tracking-wide text-slate-500">{label}</div>
      <div className="font-semibold text-slate-100">{value}</div>
    </div>
  );
}

function ActionForm({
  title,
  cta,
  suffix,
  disabled,
  onSubmit,
}: {
  title: string;
  cta: string;
  suffix: string;
  disabled?: boolean;
  onSubmit: (value: string) => void;
}) {
  const [v, setV] = useState("");
  return (
    <div className="frost-card p-4">
      <p className="mb-2 text-sm font-medium text-slate-200">{title}</p>
      <div className="mb-3 flex items-center gap-2">
        <input
          className="frost-input"
          inputMode="decimal"
          placeholder="0.0"
          value={v}
          onChange={(e) => setV(e.target.value)}
        />
        <span className="text-xs text-slate-400">{suffix}</span>
      </div>
      <button
        className="frost-btn w-full"
        disabled={disabled || !v || Number(v) <= 0}
        onClick={() => onSubmit(v)}
      >
        {cta}
      </button>
    </div>
  );
}

function LiquidatePanel({
  disabled,
  onSubmit,
}: {
  disabled?: boolean;
  onSubmit: (owner: string, amount: string) => void;
}) {
  const [owner, setOwner] = useState("");
  const [amt, setAmt] = useState("");
  return (
    <div className="frost-card mt-4 p-4">
      <p className="mb-1 text-sm font-medium text-slate-200">Liquidate a position</p>
      <p className="mb-3 text-xs text-slate-500">
        Repay an underwater borrower's USDY debt, receive their wBTC + an 8% bonus.
        Permissionless — anyone can call it.
      </p>
      <div className="flex flex-col gap-2 sm:flex-row">
        <input
          className="frost-input"
          placeholder="Borrower address (0x…)"
          value={owner}
          onChange={(e) => setOwner(e.target.value)}
        />
        <input
          className="frost-input sm:max-w-[10rem]"
          inputMode="decimal"
          placeholder="USDY to repay"
          value={amt}
          onChange={(e) => setAmt(e.target.value)}
        />
        <button
          className="frost-btn whitespace-nowrap"
          disabled={disabled || !owner.startsWith("0x") || !amt || Number(amt) <= 0}
          onClick={() => onSubmit(owner.trim(), amt)}
        >
          Liquidate
        </button>
      </div>
    </div>
  );
}
