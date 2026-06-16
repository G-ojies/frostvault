# ❄️ FrostVault

**Freeze your BTC as collateral. Borrow stablecoins against it. On Sui.**

FrostVault is a permissionless BTC-collateralized lending protocol built in Move
for the Sui Network. Deposit wrapped BTC, borrow a USD stablecoin up to a safe
loan-to-value, and — if the BTC price falls and your position goes underwater —
anyone can liquidate it, with the collateral sale routed through **Deepbook**,
Sui's native on-chain order book.

> Submitted to the **CLAY Hackathon** (Code Like a Yeti) — Lofi × Sui.

---

## Why this is Sui-native (not "a lending app that happens to be on a chain")

| Sui primitive | How FrostVault uses it |
|---|---|
| **Move linear resources** | Your loan is a `Position` *object* you own — it can't be copied or silently dropped, so a loan can't be double-spent. The risk logic is enforced by the compiler, not by convention. |
| **Object-centric model** | Each borrower holds their own `Position`; the shared `Bank` holds pooled collateral + the lending reserve. No global account table to corrupt. |
| **Programmable Transaction Blocks** | `borrow` / `repay` / `liquidate` take and return `Coin`, so a capital-free liquidator can chain **Deepbook flash loan → `liquidate` → Deepbook swap → repay** atomically in one signed transaction. |
| **Deepbook (CLOB)** | Liquidations source fair pricing/liquidity from Deepbook instead of FrostVault bootstrapping its own pool. |
| **zkLogin + sponsored gas** *(frontend)* | A judge signs in with Google and tries the full deposit→borrow→liquidate flow in ~30s without ever funding a wallet. |
| **Pyth-ready oracle** | The protocol consumes a single `price()`; on testnet it's admin-pushed (so we can crash the price live on stage), in production it's a Pyth `PriceInfoObject` adapter. |

## Architecture

```
frostvault (Move package)
├── wbtc      test wrapped-BTC collateral coin (8 dec)      [testnet faucet]
├── usdy      test USD stablecoin (6 dec)                   [testnet faucet]
├── oracle    PriceFeed (USD/BTC, 1e6 scale) + OracleCap    [admin/Pyth-pushed]
└── vault     Bank (shared pool) + Position (owned loan)
              deposit · borrow · repay · withdraw · liquidate
```

### Risk parameters (defaults)

| Param | Value | Meaning |
|---|---|---|
| Max LTV | 60% | Most you can borrow against collateral value |
| Liquidation threshold | 75% | Debt/collateral ratio that turns a position liquidatable |
| Liquidation bonus | 8% | Discount a liquidator gets on seized collateral |

**Health factor** is reported in bps: `collateral_value × liquidation_threshold ÷ debt`.
`≥ 10000` is healthy; `< 10000` is liquidatable.

## On-chain math

All USD values use a 1e6 scale (same as USDY), BTC uses 8 decimals (sats):

```
collateral_value_usd = collateral_sats × price_usd_1e6 ÷ 1e8
max_borrow_usd       = collateral_value_usd × max_ltv_bps ÷ 10000
liquidatable         ⇔ debt_usd > collateral_value_usd × liq_threshold_bps ÷ 10000
seized_sats          = repaid_usd × (1 + bonus_bps/10000) × 1e8 ÷ price_usd_1e6
```

## Build & test

```bash
sui move build
sui move test
```

## Deploy (testnet)

```bash
sui client publish --gas-budget 200000000
# then seed the reserve + mint test coins — see scripts/
```

## Status

- [x] Move package: coins, oracle, vault (deposit/borrow/repay/withdraw/liquidate) — **builds clean**
- [x] Move unit tests (LTV cap, price-crash liquidation, health factor) — **5/5 pass**
- [x] Frontend (`web/`): wallet connect, faucets, deposit/borrow/repay/withdraw, live
      health-factor bar, permissionless liquidation, admin price-crash control — **production build passes**
- [x] Deepbook flash-loan liquidation PTB (`scripts/flashloan-liquidate.ts`)
- [x] Demo video script (`docs/demo-script.md`)
- [x] **Published to Sui testnet** + reserve seeded (2,000,000 USDY)
- [x] **Full flow verified on-chain**: faucet → deposit → borrow → price-crash → permissionless liquidation
- [ ] zkLogin + sponsored gas (Enoki) — enhancement on top of wallet connect

### Live on Sui testnet

| Object | ID |
|---|---|
| **Package** | `0xa84fbade273e466646d5d493e781f5a715672c6b9ecc22117d3ee0fefe552b25` |
| Bank (shared) | `0x0ad51c8b6f674e3bccfa7597da5163c0b7d9d67629408e6ec7e9a394ff94b08d` |
| PriceFeed (shared) | `0xebe6df4e26bacbb632fd580b668ef2f53ca773f18436d12c488199a70efa4a12` |
| wBTC TreasuryCap (faucet) | `0x8e9c51acb92cbfb89f5362616177e3816fa7fc4b9bc9a4e70739a65bc201a5bf` |
| USDY TreasuryCap (faucet) | `0x1216eee8c95c6f526d6c0275cd23e9a6aa57c2546a59ae7680e0763ebfeb5118` |

**On-chain proof (testnet tx digests):**
- Deposit 0.5 wBTC: `G4TzkD4oTzvJU1JjrPHMUUasfdsfMhFCP8FAuwojn6Dp`
- Borrow 25,000 USDY: `DJe6f2N4X48yKndtYw4poJy5JBWwKF5ynCoSGLrshcUA`
- Permissionless liquidation (seized 0.45 BTC): `6knfLX7g6zDrzDfuM9Vyby1BgDSnxmL5h3Hp7vBzcrgf`

Explore: `https://suiscan.xyz/testnet/object/0xa84fbade273e466646d5d493e781f5a715672c6b9ecc22117d3ee0fefe552b25`

## Repo layout

```
frostvault/
├── sources/        Move modules (wbtc, usdy, oracle, vault)
├── tests/          Move unit tests
├── scripts/        deploy.sh, flashloan-liquidate.ts
├── web/            Next.js + @mysten/dapp-kit frontend
├── docs/           demo-script.md, deepbook-integration.md
├── README.md  ·  SUBMISSION.md
```

---

*Testnet only. wBTC/USDY here are unbacked test coins with open faucets — do not
use with real funds.*
