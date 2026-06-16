/// FrostVault — freeze your BTC as collateral, borrow USD against it.
///
/// A single shared `Bank` holds all collateral (wBTC), a reserve of the borrow
/// asset (USDY), and every borrower's `Position` in a `Table` keyed by address.
/// Borrowing is capped by `max_ltv`; once a position's debt crosses
/// `liquidation_threshold` (because the BTC price dropped), ANYONE can liquidate
/// it permissionlessly and seize the collateral at a bonus.
///
/// Sui-native design notes:
/// - Positions live INSIDE the shared `Bank` (a `Table<address, Position>`), so a
///   liquidator can act on a victim's position in a transaction the victim never
///   signs — the prerequisite for *permissionless* liquidation. (An owned object
///   could only be used by its owner, which is why positions aren't owned objects.)
/// - `borrow`, `repay`, `withdraw`, `liquidate` take/return `Coin`, so a liquidator
///   can chain a Deepbook flash loan -> `liquidate` -> Deepbook swap -> repay, all
///   atomically in one Programmable Transaction Block.
/// - Risk math is enforced by Move's type system + `assert!`, not by convention.
module frostvault::vault;

use sui::balance::{Self, Balance};
use sui::coin::{Self, Coin};
use sui::event;
use sui::table::{Self, Table};
use frostvault::wbtc::WBTC;
use frostvault::usdy::USDY;
use frostvault::oracle::{Self, PriceFeed};

// ===== Errors =====
const EZeroAmount: u64 = 0;
const EInsufficientCollateral: u64 = 1; // borrow/withdraw would breach max LTV
const EInsufficientReserve: u64 = 2; // bank doesn't have enough USDY to lend
const ERepayExceedsDebt: u64 = 3;
const EPositionHealthy: u64 = 4; // can't liquidate a healthy position
const EPositionExists: u64 = 5; // one position per address
const EPositionMissing: u64 = 6;
const EPositionNotEmpty: u64 = 7; // can't close a position with funds/debt

// ===== Constants =====
const BPS: u128 = 10_000;
/// 1 BTC = 1e8 sats (wBTC decimals).
const SATS_PER_BTC: u128 = 100_000_000;
/// Sentinel returned by `health_factor_bps` for a debt-free position.
const HEALTH_INFINITE: u64 = 0xFFFF_FFFF_FFFF_FFFF;

// ===== Objects =====

/// Admin authority: tune risk params and seed the lending reserve.
public struct AdminCap has key, store {
    id: UID,
}

/// The shared lending pool.
public struct Bank has key {
    id: UID,
    /// All deposited wBTC collateral (8 dec).
    collateral: Balance<WBTC>,
    /// USDY available to lend (6 dec).
    reserve: Balance<USDY>,
    /// Sum of all outstanding debt (6 dec).
    total_debt: u64,
    /// One position per borrower address.
    positions: Table<address, Position>,
    /// Max borrow as a fraction of collateral value, in bps (e.g. 6000 = 60%).
    max_ltv_bps: u64,
    /// Debt/collateral ratio at which a position becomes liquidatable, in bps.
    liquidation_threshold_bps: u64,
    /// Extra collateral a liquidator receives, in bps (e.g. 800 = 8%).
    liquidation_bonus_bps: u64,
}

/// A borrower's position. Stored inside the shared `Bank`.
public struct Position has store {
    /// wBTC collateral deposited (8 dec).
    collateral: u64,
    /// USDY debt outstanding (6 dec).
    debt: u64,
}

// ===== Events =====

public struct PositionOpened has copy, drop { owner: address }
public struct Deposited has copy, drop { owner: address, amount: u64 }
public struct Borrowed has copy, drop { owner: address, amount: u64 }
public struct Repaid has copy, drop { owner: address, amount: u64 }
public struct Withdrawn has copy, drop { owner: address, amount: u64 }
public struct Liquidated has copy, drop {
    owner: address,
    liquidator: address,
    debt_repaid: u64,
    collateral_seized: u64,
}

// ===== Init =====

fun init(ctx: &mut TxContext) {
    transfer::transfer(AdminCap { id: object::new(ctx) }, ctx.sender());
    transfer::share_object(Bank {
        id: object::new(ctx),
        collateral: balance::zero(),
        reserve: balance::zero(),
        total_debt: 0,
        positions: table::new(ctx),
        max_ltv_bps: 6_000, // 60%
        liquidation_threshold_bps: 7_500, // 75%
        liquidation_bonus_bps: 800, // 8%
    });
}

// ===== Admin =====

/// Seed (or top up) the USDY lending reserve.
public fun seed_reserve(_: &AdminCap, bank: &mut Bank, funds: Coin<USDY>) {
    balance::join(&mut bank.reserve, coin::into_balance(funds));
}

/// Update risk parameters.
public fun set_params(
    _: &AdminCap,
    bank: &mut Bank,
    max_ltv_bps: u64,
    liquidation_threshold_bps: u64,
    liquidation_bonus_bps: u64,
) {
    bank.max_ltv_bps = max_ltv_bps;
    bank.liquidation_threshold_bps = liquidation_threshold_bps;
    bank.liquidation_bonus_bps = liquidation_bonus_bps;
}

// ===== User actions (keyed by tx sender) =====

/// Open an empty position for the caller. Idempotent-safe: aborts if one exists.
entry fun open_position(bank: &mut Bank, ctx: &TxContext) {
    let owner = ctx.sender();
    assert!(!table::contains(&bank.positions, owner), EPositionExists);
    table::add(&mut bank.positions, owner, Position { collateral: 0, debt: 0 });
    event::emit(PositionOpened { owner });
}

/// Deposit wBTC collateral. Auto-opens a position on first deposit.
public fun deposit(bank: &mut Bank, funds: Coin<WBTC>, ctx: &mut TxContext) {
    let owner = ctx.sender();
    let amount = coin::value(&funds);
    assert!(amount > 0, EZeroAmount);
    ensure_position(bank, owner);
    let pos = table::borrow_mut(&mut bank.positions, owner);
    pos.collateral = pos.collateral + amount;
    balance::join(&mut bank.collateral, coin::into_balance(funds));
    event::emit(Deposited { owner, amount });
}

/// Borrow USDY against deposited collateral, up to `max_ltv`.
public fun borrow(
    bank: &mut Bank,
    amount: u64,
    feed: &PriceFeed,
    ctx: &mut TxContext,
): Coin<USDY> {
    let owner = ctx.sender();
    assert!(amount > 0, EZeroAmount);
    assert!(balance::value(&bank.reserve) >= amount, EInsufficientReserve);
    assert!(table::contains(&bank.positions, owner), EPositionMissing);

    let max_ltv_bps = bank.max_ltv_bps;
    let pos = table::borrow_mut(&mut bank.positions, owner);
    let new_debt = pos.debt + amount;
    let max_borrow = max_borrowable_value(pos.collateral, max_ltv_bps, feed);
    assert!((new_debt as u128) <= max_borrow, EInsufficientCollateral);

    pos.debt = new_debt;
    bank.total_debt = bank.total_debt + amount;
    event::emit(Borrowed { owner, amount });
    coin::from_balance(balance::split(&mut bank.reserve, amount), ctx)
}

/// Repay (part of) the caller's debt. Repaying more than owed aborts.
public fun repay(bank: &mut Bank, payment: Coin<USDY>, ctx: &mut TxContext) {
    let owner = ctx.sender();
    let amount = coin::value(&payment);
    assert!(amount > 0, EZeroAmount);
    assert!(table::contains(&bank.positions, owner), EPositionMissing);
    let pos = table::borrow_mut(&mut bank.positions, owner);
    assert!(amount <= pos.debt, ERepayExceedsDebt);
    pos.debt = pos.debt - amount;
    bank.total_debt = bank.total_debt - amount;
    balance::join(&mut bank.reserve, coin::into_balance(payment));
    event::emit(Repaid { owner, amount });
}

/// Withdraw collateral, provided the position stays within `max_ltv`.
public fun withdraw(
    bank: &mut Bank,
    amount: u64,
    feed: &PriceFeed,
    ctx: &mut TxContext,
): Coin<WBTC> {
    let owner = ctx.sender();
    assert!(amount > 0, EZeroAmount);
    assert!(table::contains(&bank.positions, owner), EPositionMissing);
    let max_ltv_bps = bank.max_ltv_bps;
    let pos = table::borrow_mut(&mut bank.positions, owner);
    assert!(amount <= pos.collateral, EInsufficientCollateral);
    let remaining = pos.collateral - amount;
    let max_borrow = max_borrowable_value(remaining, max_ltv_bps, feed);
    assert!((pos.debt as u128) <= max_borrow, EInsufficientCollateral);

    pos.collateral = remaining;
    event::emit(Withdrawn { owner, amount });
    coin::from_balance(balance::split(&mut bank.collateral, amount), ctx)
}

/// Permissionlessly liquidate an unhealthy position. The liquidator supplies
/// USDY to cover (part of) `owner`'s debt and receives collateral worth the
/// repaid amount plus `liquidation_bonus`. Returns the seized wBTC to the caller.
public fun liquidate(
    bank: &mut Bank,
    owner: address,
    repayment: Coin<USDY>,
    feed: &PriceFeed,
    ctx: &mut TxContext,
): Coin<WBTC> {
    assert!(table::contains(&bank.positions, owner), EPositionMissing);
    let liq_threshold_bps = bank.liquidation_threshold_bps;
    let liq_bonus_bps = bank.liquidation_bonus_bps;
    let price = oracle::price(feed) as u128;

    let repay_amt = coin::value(&repayment);
    let pos = table::borrow_mut(&mut bank.positions, owner);
    assert!(
        is_liquidatable_value(pos.collateral, pos.debt, liq_threshold_bps, feed),
        EPositionHealthy,
    );
    assert!(repay_amt > 0 && repay_amt <= pos.debt, ERepayExceedsDebt);

    // Collateral seized = repaid USD value * (1 + bonus), converted to sats.
    let bonus_value = (repay_amt as u128) * (BPS + (liq_bonus_bps as u128)) / BPS;
    let mut seize_sats = bonus_value * SATS_PER_BTC / price;
    if (seize_sats > (pos.collateral as u128)) {
        seize_sats = pos.collateral as u128;
    };
    let seize = seize_sats as u64;

    pos.debt = pos.debt - repay_amt;
    pos.collateral = pos.collateral - seize;
    bank.total_debt = bank.total_debt - repay_amt;
    balance::join(&mut bank.reserve, coin::into_balance(repayment));

    event::emit(Liquidated {
        owner,
        liquidator: ctx.sender(),
        debt_repaid: repay_amt,
        collateral_seized: seize,
    });
    coin::from_balance(balance::split(&mut bank.collateral, seize), ctx)
}

/// Close and remove the caller's position (must be empty).
entry fun close_position(bank: &mut Bank, ctx: &TxContext) {
    let owner = ctx.sender();
    assert!(table::contains(&bank.positions, owner), EPositionMissing);
    let Position { collateral, debt } = table::remove(&mut bank.positions, owner);
    assert!(collateral == 0 && debt == 0, EPositionNotEmpty);
}

// ===== Views (read-only; call via devInspect or read the Table) =====

public fun has_position(bank: &Bank, owner: address): bool {
    table::contains(&bank.positions, owner)
}

/// (collateral_sats, debt_usdy) for an address; (0,0) if no position.
public fun position_of(bank: &Bank, owner: address): (u64, u64) {
    if (!table::contains(&bank.positions, owner)) return (0, 0);
    let pos = table::borrow(&bank.positions, owner);
    (pos.collateral, pos.debt)
}

/// Collateral USD value, scaled by 1e6 (same scale as USDY / debt).
public fun collateral_value(bank: &Bank, owner: address, feed: &PriceFeed): u64 {
    let (collateral, _) = position_of(bank, owner);
    collateral_value_of(collateral, feed) as u64
}

/// Max USDY this position could owe given its collateral & the bank LTV.
public fun max_borrowable(bank: &Bank, owner: address, feed: &PriceFeed): u64 {
    let (collateral, _) = position_of(bank, owner);
    max_borrowable_value(collateral, bank.max_ltv_bps, feed) as u64
}

/// Health factor in bps: `>= 10_000` healthy, `< 10_000` liquidatable.
/// Debt-free returns max.
public fun health_factor_bps(bank: &Bank, owner: address, feed: &PriceFeed): u64 {
    let (collateral, debt) = position_of(bank, owner);
    if (debt == 0) return HEALTH_INFINITE;
    let coll_val = collateral_value_of(collateral, feed);
    let numer = coll_val * (bank.liquidation_threshold_bps as u128);
    (numer / (debt as u128)) as u64
}

public fun is_liquidatable(bank: &Bank, owner: address, feed: &PriceFeed): bool {
    let (collateral, debt) = position_of(bank, owner);
    is_liquidatable_value(collateral, debt, bank.liquidation_threshold_bps, feed)
}

public fun bank_reserve(bank: &Bank): u64 { balance::value(&bank.reserve) }
public fun bank_collateral(bank: &Bank): u64 { balance::value(&bank.collateral) }
public fun bank_total_debt(bank: &Bank): u64 { bank.total_debt }
public fun bank_max_ltv_bps(bank: &Bank): u64 { bank.max_ltv_bps }
public fun bank_liquidation_threshold_bps(bank: &Bank): u64 { bank.liquidation_threshold_bps }
public fun bank_liquidation_bonus_bps(bank: &Bank): u64 { bank.liquidation_bonus_bps }

// ===== Internal math =====

fun ensure_position(bank: &mut Bank, owner: address) {
    if (!table::contains(&bank.positions, owner)) {
        table::add(&mut bank.positions, owner, Position { collateral: 0, debt: 0 });
        event::emit(PositionOpened { owner });
    }
}

/// Collateral value in 1e6-scaled USD: sats * price_6dec / 1e8.
fun collateral_value_of(collateral_sats: u64, feed: &PriceFeed): u128 {
    (collateral_sats as u128) * (oracle::price(feed) as u128) / SATS_PER_BTC
}

fun max_borrowable_value(collateral_sats: u64, max_ltv_bps: u64, feed: &PriceFeed): u128 {
    collateral_value_of(collateral_sats, feed) * (max_ltv_bps as u128) / BPS
}

fun is_liquidatable_value(
    collateral_sats: u64,
    debt: u64,
    liq_threshold_bps: u64,
    feed: &PriceFeed,
): bool {
    if (debt == 0) return false;
    let coll_val = collateral_value_of(collateral_sats, feed);
    let threshold_value = coll_val * (liq_threshold_bps as u128) / BPS;
    (debt as u128) > threshold_value
}

// ===== Test-only =====

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx)
}
