# FrostVault — CLAY Hackathon Submission

> Draft. Fields map 1:1 to the CLAY submission checklist (Core Identity,
> Development & Demonstration, Technical Deployment). Placeholders marked `TBD`
> get filled after testnet deploy + video record.

## Core Identity & Documentation

**Project Title:** FrostVault

**Description (short, for the form):**
> FrostVault lets you freeze your Bitcoin as collateral and borrow a USD
> stablecoin against it — fully on Sui. Your loan is a Move *object* you own,
> borrowing is capped by a safe loan-to-value, and when BTC drops anyone can
> liquidate underwater positions permissionlessly, with the collateral sale
> routed through Deepbook's on-chain liquidity. Sign in with Google (zkLogin)
> and try the whole flow in 30 seconds — no wallet setup, no gas.

**Description (one-liner):** Permissionless BTC-collateralized stablecoin
borrowing on Sui, with Deepbook-routed liquidations.

**Why it matters:** BTC is the largest crypto asset but mostly sits idle.
FrostVault turns it into productive collateral on Sui without selling it —
a core DeFi primitive, built to show off what only Sui makes clean:
compiler-enforced loan safety (Move linear resources), atomic
flash-loan liquidations (PTBs + Deepbook), and Web2-grade onboarding
(zkLogin + sponsored gas).

**Project Logo:** 1:1, JPG/PNG — TBD (frost-blue vault / BTC-in-ice mark).

**Additional Documentation:** This repo's `README.md` (architecture + on-chain
math) + GitBook — TBD.

## Development & Demonstration

**Public GitHub Repository:** https://github.com/G-ojies/frostvault ✅

**Demo Video (3–5 min, YouTube):** TBD — script in `docs/demo-script.md`.
Planned beats:
1. (0:00) The problem: idle BTC, and why object-model lending is safer.
2. (0:30) zkLogin: sign in with Google, zero wallet setup, sponsored gas.
3. (1:00) Deposit wBTC → borrow USDY; watch the health-factor bar.
4. (2:00) Crash the BTC price (admin oracle) live; position goes red.
5. (2:30) Permissionless liquidation via a Deepbook flash loan, in ONE
   signed transaction (capital-free liquidator). Show the explorer txn.
6. (3:30) Recap the Sui-native wins; call to action.

**Website (optional, recommended):** TBD — Vercel deploy of the frontend.

## Technical Deployment — LIVE on Sui testnet

**Package ID:** `0xa84fbade273e466646d5d493e781f5a715672c6b9ecc22117d3ee0fefe552b25`
- Bank (shared): `0x0ad51c8b6f674e3bccfa7597da5163c0b7d9d67629408e6ec7e9a394ff94b08d`
- PriceFeed (shared): `0xebe6df4e26bacbb632fd580b668ef2f53ca773f18436d12c488199a70efa4a12`
- WBTC TreasuryCap (faucet): `0x8e9c51acb92cbfb89f5362616177e3816fa7fc4b9bc9a4e70739a65bc201a5bf`
- USDY TreasuryCap (faucet): `0x1216eee8c95c6f526d6c0275cd23e9a6aa57c2546a59ae7680e0763ebfeb5118`
- AdminCap: `0x6706853a4a23f087749cfc0c3d6634691b8ac61bb4a282dcf0f91d9c68ce37b7`
- OracleCap: `0xbdb438f78bdda7ea673c6895c78b1034edca5ecb2a6301a8ca9d5e9aa23a703c`

**On-chain proof (testnet tx digests):**
- Deposit 0.5 wBTC: `G4TzkD4oTzvJU1JjrPHMUUasfdsfMhFCP8FAuwojn6Dp`
- Borrow 25,000 USDY: `DJe6f2N4X48yKndtYw4poJy5JBWwKF5ynCoSGLrshcUA`
- Permissionless liquidation, seized 0.45 BTC: `6knfLX7g6zDrzDfuM9Vyby1BgDSnxmL5h3Hp7vBzcrgf`

Explorer: https://suiscan.xyz/testnet/object/0xa84fbade273e466646d5d493e781f5a715672c6b9ecc22117d3ee0fefe552b25

**Deepbook:** liquidation composes inside a Deepbook V3 flash loan
(`scripts/flashloan-liquidate.ts`); requires a WBTC/USDY pool for the atomic
close-the-loop (mainnet path). Core liquidation works today with the liquidator
supplying USDY.

## Judging-criteria self-check

| Criterion | How FrostVault scores |
|---|---|
| **Sui-nativeness** | Loan-as-object, PTB-composed flash-loan liquidation, Deepbook, zkLogin — none of which port cleanly off Sui. |
| **Technical depth** | Real lending math, permissionless liquidation, oracle abstraction, Move test suite. |
| **UX** | Google sign-in + sponsored gas → judge tries it in 30s, no funds needed. |
| **Completeness** | Deployed testnet package + live frontend + working liquidation demo. |
| **Novelty** | BTC-collateral DeFi is proven, but the object-model + atomic flash-liquidation framing is distinctive. |

## Team

**Team / Project Lead Name:** Great Ojietohamen (GitHub: G-ojies)
**Email:** scarletmacaw1@live.com (TBD confirm)
**Primary Contact Handle:** TBD (Telegram / Discord / X)
