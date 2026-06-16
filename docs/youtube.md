# YouTube — title & description

## Title (pick one)

1. **FrostVault — Freeze your BTC, borrow on Sui (CLAY Hackathon)**  ← recommended
2. FrostVault: BTC-collateral lending on Sui with one-click liquidations
3. I built a Bitcoin lending protocol on Sui in Move — FrostVault (CLAY)

## Description

```
FrostVault lets you freeze your Bitcoin as collateral and borrow a USD
stablecoin against it — fully on Sui, written in Move. Borrowing is capped by a
safe loan-to-value, and when BTC drops, ANYONE can liquidate underwater
positions permissionlessly, with the collateral sale composable through a
Deepbook flash loan. Built for the CLAY Hackathon (Code Like a Yeti · Lofi × Sui).

▶ Try it live: https://frostvault-six.vercel.app
▶ Code (open source): https://github.com/G-ojies/frostvault
▶ On-chain (Sui testnet): package 0xa84fbade273e466646d5d493e781f5a715672c6b9ecc22117d3ee0fefe552b25

What makes it Sui-native (not "a lending app that happens to be on a chain"):
• Your loan is a Move resource the compiler guarantees can't be double-spent
• Positions live in a shared Bank, so liquidation is truly permissionless
• liquidate() takes/returns Coin, so a liquidator can flash-borrow from Deepbook,
  repay your debt, seize discounted collateral, and repay — atomically, in one
  Programmable Transaction Block, with zero capital
• Pyth-ready price oracle (admin-pushed on testnet so we can crash BTC live)

Chapters
0:00  The problem: idle BTC
0:25  Connect + grab test BTC
0:55  Deposit collateral, borrow USDY
1:40  BTC price crashes — position goes underwater
2:30  Permissionless liquidation (Deepbook flash-loan, capital-free)
3:20  Why this only works cleanly on Sui

Stack: Sui · Move · @mysten/dapp-kit · Deepbook V3 · Next.js
Risk params: 60% max LTV · 75% liquidation threshold · 8% liquidation bonus

#Sui #Move #DeFi #Bitcoin #Deepbook #CLAYHackathon #Web3
```

## Pinned comment (optional)
```
Built solo for the CLAY Hackathon. Deployed and verified on Sui testnet —
deposit → borrow → price-crash → permissionless liquidation all run on-chain.
Feedback welcome 🏔️
```
