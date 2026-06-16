/// Test wrapped-BTC collateral coin for FrostVault.
/// TESTNET ONLY: the deployer holds the TreasuryCap and can mint freely so
/// judges/users can grab collateral without a real bridge. In production this
/// type would be replaced by a canonical bridged BTC (e.g. Wormhole/sBTC).
#[allow(deprecated_usage)]
module frostvault::wbtc;

use sui::coin::{Self, TreasuryCap};

/// One-time witness.
public struct WBTC has drop {}

const DECIMALS: u8 = 8; // BTC convention: 1 BTC = 1e8 sats
/// Default faucet drip: 0.5 BTC.
const FAUCET_AMOUNT: u64 = 50_000_000;

/// TESTNET ONLY: the TreasuryCap is shared so anyone can self-serve test
/// collateral via `faucet`/`mint`. This is an UNLIMITED mint and must never
/// ship to mainnet — there a canonical bridged BTC type would replace this.
fun init(witness: WBTC, ctx: &mut TxContext) {
    let (treasury, metadata) = coin::create_currency(
        witness,
        DECIMALS,
        b"wBTC",
        b"FrostVault Bitcoin",
        b"Test wrapped BTC used as collateral in FrostVault (testnet only).",
        option::none(),
        ctx,
    );
    transfer::public_freeze_object(metadata);
    transfer::public_share_object(treasury);
}

/// Self-serve faucet: mint the default drip to the caller.
entry fun faucet(treasury: &mut TreasuryCap<WBTC>, ctx: &mut TxContext) {
    mint(treasury, FAUCET_AMOUNT, ctx.sender(), ctx)
}

/// Mint test collateral to a recipient.
public fun mint(
    treasury: &mut TreasuryCap<WBTC>,
    amount: u64,
    recipient: address,
    ctx: &mut TxContext,
) {
    let c = coin::mint(treasury, amount, ctx);
    transfer::public_transfer(c, recipient);
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(WBTC {}, ctx)
}
