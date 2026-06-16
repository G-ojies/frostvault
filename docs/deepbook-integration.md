# Deepbook V3 integration notes (testnet)

Source of truth for IDs: the `@mysten/deepbook-v3` SDK constants file
(`packages/deepbook-v3/src/utils/constants.ts`) — **read IDs from there, don't
hardcode**; the package ID changes on every contract upgrade.

## Testnet IDs (SDK v1.5.0 — verify before deploy)

| Object | Testnet ID |
|---|---|
| `DEEPBOOK_PACKAGE_ID` | `0x22be4cade64bf2d02412c7e8d0e8beea2f78828b948118d46735315409371a3c` |
| `REGISTRY_ID` | `0x7c256edbda983a2cd6f946655f4bf3f00a41043993781f8674a7046e8c0e11d1` |
| `DEEP_TREASURY_ID` | `0x69fffdae0075f8f71f4fa793549c11079266910e8905169845af1f5d00e09dcb` |
| DEEP coin type | `0x36dbef866a1d62bf7328989a10fb2f07d769f4ee587c0de4a0a256e57e0a58a8::deep::DEEP` (6 dec) |

## How FrostVault uses Deepbook

FrostVault's `liquidate()` is **Aave/Compound-style**: the liquidator supplies
USDY and receives discounted wBTC. It takes a `Coin<USDY>` and returns a
`Coin<WBTC>`, so it composes inside a Deepbook **flash loan** in a single PTB:

```
borrow_flashloan_quote(pool, amount)  -> (USDY, FlashLoan hot-potato)
  vault::liquidate(bank, victim, USDY, feed) -> WBTC (discounted)
  [swap a slice of WBTC -> USDY on Deepbook to close the loop]
return_flashloan_quote(pool, USDY, FlashLoan)   // exact amount, fee-free
```

This makes liquidation **capital-free**: a bot needs zero stablecoin inventory.

### Flash loan Move API (`deepbook::pool`)
- `borrow_flashloan_base<B,Q>(pool, base_amount, ctx) -> (Coin<B>, FlashLoan)`
- `borrow_flashloan_quote<B,Q>(pool, quote_amount, ctx) -> (Coin<Q>, FlashLoan)`
- `return_flashloan_base<B,Q>(pool, coin, flash_loan)`
- `return_flashloan_quote<B,Q>(pool, coin, flash_loan)`

`FlashLoan` has **no abilities** (hot potato) — must be returned in the same PTB
or the whole tx aborts. Repay exactly `borrow_quantity`, same asset, **no fee**.

### SDK sketch (`@mysten/deepbook-v3` v1.5.0)
```ts
const tx = new Transaction();
const [usdy, loan] = tx.add(db.flashLoans.borrowQuoteAsset('WBTC_USDY', amount));
// ...use usdy in vault::liquidate, produce repayment...
const remainder = tx.add(db.flashLoans.returnQuoteAsset('WBTC_USDY', amount, usdy, loan));
tx.transferObjects([remainder], address);
```
Register custom coins/pools in the `DeepBookClient` config via the `coins` and
`pools` maps (merged over network defaults).

## Decision (MVP scope)

1. **Primary, fully-working demo:** liquidator supplies USDY → receives discounted
   wBTC. Self-contained, no external liquidity dependency, works on testnet today.
2. **Deepbook hero (flash loan):** wrap `liquidate()` in a Deepbook flash-loan PTB
   to show capital-free liquidation. Atomic close-the-loop requires the seized
   collateral to be tradeable on Deepbook; on testnet that means either:
   - using Deepbook reference assets that already have liquid pools, or
   - creating a WBTC/USDY permissionless pool (500 DEEP, fragile/illiquid).
   Build the flash-loan PTB and run it on testnet; document the pool path as the
   mainnet route. Do NOT block the core demo on it.

### Gotchas
- Deepbook swaps charge taker fees **in DEEP** — a liquidator PTB needs a small
  DEEP balance. Flash loans themselves are free.
- `create_permissionless_pool` is NOT wrapped by the public SDK — call via raw
  `tx.moveCall` if we go that route.
