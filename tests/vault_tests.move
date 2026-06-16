#[test_only]
module frostvault::vault_tests;

use sui::coin;
use sui::test_scenario::{Self as ts, Scenario};
use sui::test_utils::assert_eq;
use frostvault::wbtc::WBTC;
use frostvault::usdy::USDY;
use frostvault::oracle::{Self, PriceFeed, OracleCap};
use frostvault::vault::{Self, Bank, AdminCap};

const ADMIN: address = @0xAD;
const ALICE: address = @0xA11CE;
const BOB: address = @0xB0B; // liquidator

const ONE_BTC: u64 = 100_000_000; // 1e8 sats
const ONE_USD: u64 = 1_000_000; // 1e6 micro-USDY
const PRICE_70K: u64 = 70_000_000000;

// Publish the modules and seed the lending reserve with 1,000,000 USDY.
fun setup(sc: &mut Scenario) {
    vault::init_for_testing(sc.ctx());
    oracle::init_for_testing(sc.ctx());
    sc.next_tx(ADMIN);
    let cap = sc.take_from_sender<AdminCap>();
    let mut bank = sc.take_shared<Bank>();
    let reserve = coin::mint_for_testing<USDY>(1_000_000 * ONE_USD, sc.ctx());
    vault::seed_reserve(&cap, &mut bank, reserve);
    ts::return_shared(bank);
    sc.return_to_sender(cap);
}

// Alice deposits `btc` sats of collateral.
fun alice_deposit(sc: &mut Scenario, btc: u64) {
    sc.next_tx(ALICE);
    let mut bank = sc.take_shared<Bank>();
    let coll = coin::mint_for_testing<WBTC>(btc, sc.ctx());
    vault::deposit(&mut bank, coll, sc.ctx());
    ts::return_shared(bank);
}

// Alice borrows `usd` micro-USDY, keeps the loan.
fun alice_borrow(sc: &mut Scenario, usd: u64) {
    sc.next_tx(ALICE);
    let mut bank = sc.take_shared<Bank>();
    let feed = sc.take_shared<PriceFeed>();
    let loan = vault::borrow(&mut bank, usd, &feed, sc.ctx());
    transfer::public_transfer(loan, ALICE);
    ts::return_shared(bank);
    ts::return_shared(feed);
}

fun admin_set_price(sc: &mut Scenario, price: u64) {
    sc.next_tx(ADMIN);
    let ocap = sc.take_from_sender<OracleCap>();
    let mut feed = sc.take_shared<PriceFeed>();
    oracle::update_price(&ocap, &mut feed, price, sc.ctx());
    ts::return_shared(feed);
    sc.return_to_sender(ocap);
}

#[test]
fun deposit_and_borrow_within_ltv() {
    let mut sc = ts::begin(ADMIN);
    setup(&mut sc);
    alice_deposit(&mut sc, ONE_BTC); // $100k @ initial price

    sc.next_tx(ALICE);
    {
        let mut bank = sc.take_shared<Bank>();
        let feed = sc.take_shared<PriceFeed>();
        // $100k collateral, 60% LTV => $60k borrowable.
        assert_eq(vault::collateral_value(&bank, ALICE, &feed), 100_000 * ONE_USD);
        assert_eq(vault::max_borrowable(&bank, ALICE, &feed), 60_000 * ONE_USD);

        let loan = vault::borrow(&mut bank, 50_000 * ONE_USD, &feed, sc.ctx());
        assert_eq(coin::value(&loan), 50_000 * ONE_USD);
        let (collateral, debt) = vault::position_of(&bank, ALICE);
        assert_eq(collateral, ONE_BTC);
        assert_eq(debt, 50_000 * ONE_USD);
        // HF = collateral_value * 0.75 / debt = 75k/50k = 1.5x = 15000 bps.
        assert_eq(vault::health_factor_bps(&bank, ALICE, &feed), 15_000);
        assert!(!vault::is_liquidatable(&bank, ALICE, &feed), 0);

        transfer::public_transfer(loan, ALICE);
        ts::return_shared(bank);
        ts::return_shared(feed);
    };
    ts::end(sc);
}

#[test]
#[expected_failure(abort_code = vault::EInsufficientCollateral)]
fun borrow_over_ltv_aborts() {
    let mut sc = ts::begin(ADMIN);
    setup(&mut sc);
    alice_deposit(&mut sc, ONE_BTC);

    sc.next_tx(ALICE);
    let mut bank = sc.take_shared<Bank>();
    let feed = sc.take_shared<PriceFeed>();
    // $61k against $100k @ 60% LTV — must abort.
    let loan = vault::borrow(&mut bank, 61_000 * ONE_USD, &feed, sc.ctx());
    transfer::public_transfer(loan, ALICE);
    ts::return_shared(bank);
    ts::return_shared(feed);
    ts::end(sc);
}

#[test]
fun price_crash_makes_liquidatable_then_liquidate() {
    let mut sc = ts::begin(ADMIN);
    setup(&mut sc);
    alice_deposit(&mut sc, ONE_BTC);
    alice_borrow(&mut sc, 55_000 * ONE_USD); // HF = 75k/55k ≈ 1.36x, healthy

    // BTC crashes to $70k: threshold value = 70k*0.75 = $52.5k < $55k debt.
    admin_set_price(&mut sc, PRICE_70K);

    sc.next_tx(BOB);
    {
        let mut bank = sc.take_shared<Bank>();
        let feed = sc.take_shared<PriceFeed>();
        assert!(vault::is_liquidatable(&bank, ALICE, &feed), 0);

        let (coll_before, _) = vault::position_of(&bank, ALICE);
        let repayment = coin::mint_for_testing<USDY>(55_000 * ONE_USD, sc.ctx());
        let seized = vault::liquidate(&mut bank, ALICE, repayment, &feed, sc.ctx());

        // seized = 55k * 1.08 / 70k BTC, in sats.
        let expected_seize =
            ((55_000u128 * (ONE_USD as u128)) * 10_800 / 10_000) * (ONE_BTC as u128)
                / (70_000u128 * (ONE_USD as u128));
        assert_eq(coin::value(&seized), expected_seize as u64);
        let (coll_after, debt_after) = vault::position_of(&bank, ALICE);
        assert_eq(debt_after, 0);
        assert_eq(coll_after, coll_before - (expected_seize as u64));

        transfer::public_transfer(seized, BOB);
        ts::return_shared(bank);
        ts::return_shared(feed);
    };
    ts::end(sc);
}

#[test]
#[expected_failure(abort_code = vault::EPositionHealthy)]
fun cannot_liquidate_healthy_position() {
    let mut sc = ts::begin(ADMIN);
    setup(&mut sc);
    alice_deposit(&mut sc, ONE_BTC);
    alice_borrow(&mut sc, 50_000 * ONE_USD); // healthy

    sc.next_tx(BOB);
    let mut bank = sc.take_shared<Bank>();
    let feed = sc.take_shared<PriceFeed>();
    let repayment = coin::mint_for_testing<USDY>(50_000 * ONE_USD, sc.ctx());
    let seized = vault::liquidate(&mut bank, ALICE, repayment, &feed, sc.ctx());
    transfer::public_transfer(seized, BOB);
    ts::return_shared(bank);
    ts::return_shared(feed);
    ts::end(sc);
}

#[test]
fun repay_then_withdraw_all() {
    let mut sc = ts::begin(ADMIN);
    setup(&mut sc);
    alice_deposit(&mut sc, ONE_BTC);
    alice_borrow(&mut sc, 40_000 * ONE_USD);

    // Repay the full loan, then withdraw all collateral.
    sc.next_tx(ALICE);
    {
        let mut bank = sc.take_shared<Bank>();
        let feed = sc.take_shared<PriceFeed>();
        let loan = sc.take_from_sender<coin::Coin<USDY>>();
        vault::repay(&mut bank, loan, sc.ctx());
        let (_c, debt) = vault::position_of(&bank, ALICE);
        assert_eq(debt, 0);

        let returned = vault::withdraw(&mut bank, ONE_BTC, &feed, sc.ctx());
        assert_eq(coin::value(&returned), ONE_BTC);
        let (coll, _d) = vault::position_of(&bank, ALICE);
        assert_eq(coll, 0);

        transfer::public_transfer(returned, ALICE);
        ts::return_shared(bank);
        ts::return_shared(feed);
    };
    ts::end(sc);
}
