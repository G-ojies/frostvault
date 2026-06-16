# FrostVault — Demo Video Script (3–5 min)

Target: **3:30–4:00**. YouTube, 1080p. Record the deployed testnet app + a
Suiscan tab. Keep cuts tight; show real transactions landing.

Pre-roll setup (don't record):
- Two browser profiles/windows: **Alice** (borrower) and **Bob** (liquidator),
  each with a Sui wallet on testnet. Or one wallet + the admin demo control.
- App running at the deployed URL. Suiscan open on the package.
- Both wallets pre-funded with a little SUI for gas; Alice has faucet wBTC.

---

### 0:00–0:25 · Hook + problem
> "This is FrostVault. Bitcoin is the biggest asset in crypto — and most of it
> just sits there. FrostVault lets you freeze your BTC as collateral and borrow
> a dollar stablecoin against it, without selling. Built entirely on Sui, in
> Move. And here's what makes it Sui-native, not just 'a lending app on a chain.'"

Screen: landing hero ("Freeze your BTC. Borrow on Sui."). Quick.

### 0:25–0:55 · Onboard + faucet
> "I'll connect a wallet — on mainnet this would be a Google sign-in via zkLogin,
> so there's no seed phrase and no gas to fund. Let me grab some test BTC."

Screen: Connect wallet → click **+ wBTC** faucet → balance updates to 0.5 wBTC.

### 0:55–1:40 · Deposit + borrow
> "I deposit half a Bitcoin as collateral. At a hundred-thousand-dollar BTC
> price, that's fifty-thousand dollars of collateral. FrostVault lets me borrow
> up to sixty percent of that — thirty-thousand USDY. I'll take twenty-five."

Screen: Deposit `0.5` wBTC (tx lands). Borrow `25000` USDY (tx lands).
Point at the **health-factor bar** — green, ~1.5x.
> "My loan isn't a database row — it's a Move object, owned by me, that the
> compiler guarantees can't be double-spent."

### 1:40–2:30 · Crash the price → underwater
> "Now the market turns. Watch the health factor. I'll drop the BTC price from
> a hundred-thousand to seventy-thousand."

Screen: click **Crash BTC → $70k** (admin oracle control). The bar animates
green → red, label flips to **LIQUIDATABLE**.
> "My collateral is now worth thirty-five-thousand. Against a twenty-five-
> thousand-dollar loan, I've crossed the liquidation threshold. On mainnet this
> price comes from Pyth — here it's an admin control so I can show it live."

### 2:30–3:20 · Permissionless liquidation (the hero)
> "Here's the Sui-native part. Anyone can now liquidate me — permissionlessly.
> Bob the liquidator repays my debt and seizes my collateral at an eight-percent
> discount. And he doesn't even need capital up front: in a single Programmable
> Transaction Block, he flash-borrows USDY from Deepbook, repays my loan, takes
> the discounted BTC, and repays the flash loan — atomically. No inventory, no
> risk. If any step fails, the whole transaction reverts."

Screen: switch to Bob → Liquidate panel → paste Alice's address + repay amount →
**Liquidate** (tx lands). Alice's position clears; Bob receives wBTC.
Cut to **Suiscan**: show the liquidation transaction + the events.

### 3:20–3:50 · Why Sui + close
> "That's FrostVault: a real BTC-collateral lending market where your position
> is an object you own, liquidations are permissionless and capital-free through
> Deepbook, and onboarding is a Google login. None of this composes as cleanly
> anywhere but Sui. Code's open-source, it's live on testnet — link below.
> Freeze your BTC. Borrow on Sui."

Screen: back to the dashboard, healthy state. End card with repo + package ID.

---

### Shot list / B-roll
- Health-factor bar transition (green→red) — the money shot, hold on it.
- Suiscan: package page, the liquidate tx, emitted `Liquidated` event.
- One PTB in code (scripts/flashloan-liquidate.ts) on screen for ~3s during the
  flash-loan line.

### Recording tips
- Pre-mint coins so no waiting on faucets on camera.
- If running solo, use one wallet as both Alice and Bob; narrate the role switch.
- Keep each tx confirmation visible but don't dwell — speed-ramp the waits.
