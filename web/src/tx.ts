import { Transaction, coinWithBalance } from "@mysten/sui/transactions";
import {
  PACKAGE_ID,
  BANK_ID,
  PRICE_FEED_ID,
  WBTC_TREASURY_ID,
  USDY_TREASURY_ID,
  ORACLE_CAP_ID,
  WBTC_TYPE,
  USDY_TYPE,
} from "./config";

const target = (fn: string) => `${PACKAGE_ID}::${fn}`;

/** Mint the default wBTC faucet drip to the caller. */
export function faucetWbtcTx(): Transaction {
  const tx = new Transaction();
  tx.moveCall({
    target: target("wbtc::faucet"),
    arguments: [tx.object(WBTC_TREASURY_ID)],
  });
  return tx;
}

/** Mint the default USDY faucet drip to the caller. */
export function faucetUsdyTx(): Transaction {
  const tx = new Transaction();
  tx.moveCall({
    target: target("usdy::faucet"),
    arguments: [tx.object(USDY_TREASURY_ID)],
  });
  return tx;
}

/** Deposit wBTC collateral (auto-opens a position). */
export function depositTx(amountSats: bigint): Transaction {
  const tx = new Transaction();
  const coin = coinWithBalance({ type: WBTC_TYPE, balance: amountSats });
  tx.moveCall({
    target: target("vault::deposit"),
    arguments: [tx.object(BANK_ID), coin],
  });
  return tx;
}

/** Borrow USDY against collateral; sends the loan to the caller. */
export function borrowTx(amountUsdy: bigint, sender: string): Transaction {
  const tx = new Transaction();
  const [loan] = tx.moveCall({
    target: target("vault::borrow"),
    arguments: [tx.object(BANK_ID), tx.pure.u64(amountUsdy), tx.object(PRICE_FEED_ID)],
  });
  tx.transferObjects([loan], tx.pure.address(sender));
  return tx;
}

/** Repay (part of) the caller's debt. */
export function repayTx(amountUsdy: bigint): Transaction {
  const tx = new Transaction();
  const payment = coinWithBalance({ type: USDY_TYPE, balance: amountUsdy });
  tx.moveCall({
    target: target("vault::repay"),
    arguments: [tx.object(BANK_ID), payment],
  });
  return tx;
}

/** Withdraw collateral; sends the wBTC to the caller. */
export function withdrawTx(amountSats: bigint, sender: string): Transaction {
  const tx = new Transaction();
  const [coin] = tx.moveCall({
    target: target("vault::withdraw"),
    arguments: [tx.object(BANK_ID), tx.pure.u64(amountSats), tx.object(PRICE_FEED_ID)],
  });
  tx.transferObjects([coin], tx.pure.address(sender));
  return tx;
}

/**
 * Liquidate an unhealthy position: supply USDY, receive discounted wBTC.
 * This is the composable primitive a Deepbook flash-loan liquidator wraps
 * (see scripts/flashloan-liquidate.ts).
 */
export function liquidateTx(
  owner: string,
  repayUsdy: bigint,
  sender: string,
): Transaction {
  const tx = new Transaction();
  const repayment = coinWithBalance({ type: USDY_TYPE, balance: repayUsdy });
  const [seized] = tx.moveCall({
    target: target("vault::liquidate"),
    arguments: [
      tx.object(BANK_ID),
      tx.pure.address(owner),
      repayment,
      tx.object(PRICE_FEED_ID),
    ],
  });
  tx.transferObjects([seized], tx.pure.address(sender));
  return tx;
}

/** Admin-only: push a new BTC price (USD * 1e6). Demo control for crashing price. */
export function setPriceTx(newPrice6dec: bigint): Transaction {
  const tx = new Transaction();
  tx.moveCall({
    target: target("oracle::update_price"),
    arguments: [
      tx.object(ORACLE_CAP_ID),
      tx.object(PRICE_FEED_ID),
      tx.pure.u64(newPrice6dec),
    ],
  });
  return tx;
}
