/**
 * Capital-free liquidation: wrap FrostVault's `vault::liquidate` inside a
 * Deepbook V3 flash loan, all in ONE Programmable Transaction Block.
 *
 * The liquidator needs ZERO stablecoin inventory. In a single atomic tx:
 *   1. flash-borrow USDY from a Deepbook pool          (free, no collateral)
 *   2. vault::liquidate(victim) -> repay debt, seize discounted wBTC
 *   3. swap the seized wBTC -> USDY on Deepbook
 *   4. repay the flash loan exactly
 *   5. keep the spread (the 8% liquidation bonus, minus gas + DEEP fees)
 * If any step fails, the whole transaction reverts — the `FlashLoan` hot-potato
 * cannot be dropped, so the borrow MUST be repaid in the same PTB.
 *
 * REQUIREMENT (honest): step 1 & 3 need a Deepbook pool for the WBTC/USDY pair.
 * Custom coins have no pool by default; create one permissionlessly (500 DEEP)
 * or point this at a pool of Deepbook reference assets. Without a pool, use the
 * frontend's plain liquidation (liquidator supplies USDY) — same `vault::liquidate`
 * primitive, just funded from the liquidator's own balance. See
 * docs/deepbook-integration.md.
 *
 * Run:  cd scripts && npm i && SUI_KEY=<bech32 suiprivkey...> npm run flashloan-liquidate -- <victimAddress> <repayUsdy>
 */
import { SuiClient, getFullnodeUrl } from "@mysten/sui/client";
import { Transaction } from "@mysten/sui/transactions";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { decodeSuiPrivateKey } from "@mysten/sui/cryptography";
import { DeepBookClient } from "@mysten/deepbook-v3";
import { readFileSync } from "node:fs";

// ---- Load deployed FrostVault IDs from deploy.local.json ----
const deploy = JSON.parse(readFileSync(new URL("../deploy.local.json", import.meta.url), "utf8"));
const PACKAGE_ID: string = deploy.packageId;
const BANK_ID: string = deploy.bankId;
const PRICE_FEED_ID: string = deploy.priceFeedId;

const WBTC_TYPE = `${PACKAGE_ID}::wbtc::WBTC`;
const USDY_TYPE = `${PACKAGE_ID}::usdy::USDY`;

// The Deepbook pool used for the flash loan + collateral swap.
// Set this to your WBTC/USDY pool (base = WBTC, quote = USDY).
const POOL_KEY = "WBTC_USDY";
const POOL_ID = process.env.POOL_ID ?? "0xTODO_DEEPBOOK_WBTC_USDY_POOL";

// ---- CLI args ----
const [victim, repayHuman] = process.argv.slice(2);
if (!victim || !repayHuman) {
  console.error("usage: npm run flashloan-liquidate -- <victimAddress> <repayUsdy>");
  process.exit(1);
}
const repayUsdy = BigInt(Math.floor(Number(repayHuman) * 1e6)); // USDY 6 dec

// ---- Keypair ----
const keyStr = process.env.SUI_KEY;
if (!keyStr) throw new Error("Set SUI_KEY to a bech32 suiprivkey... string");
const { secretKey } = decodeSuiPrivateKey(keyStr);
const keypair = Ed25519Keypair.fromSecretKey(secretKey);
const sender = keypair.getPublicKey().toSuiAddress();

const client = new SuiClient({ url: getFullnodeUrl("testnet") });

const db = new DeepBookClient({
  client,
  address: sender,
  env: "testnet",
  coins: {
    WBTC: { address: PACKAGE_ID, type: WBTC_TYPE, scalar: 1e8 },
    USDY: { address: PACKAGE_ID, type: USDY_TYPE, scalar: 1e6 },
  },
  pools: {
    [POOL_KEY]: { address: POOL_ID, baseCoin: "WBTC", quoteCoin: "USDY" },
  },
});

async function main() {
  const tx = new Transaction();

  // 1) Flash-borrow USDY (quote asset) — free, no collateral.
  const borrow = Number(repayUsdy) / 1e6;
  const [usdy, flashLoan] = tx.add(db.flashLoans.borrowQuoteAsset(POOL_KEY, borrow));

  // 2) Liquidate the victim: hand over the borrowed USDY, receive discounted wBTC.
  const [seizedWbtc] = tx.moveCall({
    target: `${PACKAGE_ID}::vault::liquidate`,
    arguments: [
      tx.object(BANK_ID),
      tx.pure.address(victim),
      usdy, // borrowed USDY funds the debt repayment
      tx.object(PRICE_FEED_ID),
    ],
  });

  // 3) Swap the seized wBTC back to USDY on Deepbook to repay the loan.
  //    (swapExactBaseForQuote consumes the wBTC coin object directly.)
  const [, usdyOut, deepOut] = tx.add(
    db.deepBook.swapExactBaseForQuote({
      poolKey: POOL_KEY,
      baseCoin: seizedWbtc,
      minQuote: borrow, // must cover the repayment
      deepCoin: undefined, // pass a DEEP coin if the pool charges taker fees in DEEP
    } as any),
  );

  // 4) Repay the flash loan exactly (fee-free).
  const remainder = tx.add(db.flashLoans.returnQuoteAsset(POOL_KEY, borrow, usdyOut, flashLoan));

  // 5) Keep the profit + any leftover coins.
  tx.transferObjects([remainder, deepOut], tx.pure.address(sender));

  const res = await client.signAndExecuteTransaction({
    signer: keypair,
    transaction: tx,
    options: { showEffects: true, showBalanceChanges: true },
  });
  console.log("digest:", res.digest);
  console.log("status:", res.effects?.status);
  console.log("balance changes:", JSON.stringify(res.balanceChanges, null, 2));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
