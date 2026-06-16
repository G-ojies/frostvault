/// Test USD stablecoin (USDY) borrowed against wBTC collateral in FrostVault.
/// TESTNET ONLY: deployer holds the TreasuryCap to seed the lending reserve.
#[allow(deprecated_usage)]
module frostvault::usdy;

use sui::coin::{Self, TreasuryCap};

/// One-time witness.
public struct USDY has drop {}

const DECIMALS: u8 = 6; // stablecoin convention: 1 USDY = 1e6 micro-units
/// Default faucet drip: 10,000 USDY.
const FAUCET_AMOUNT: u64 = 10_000_000_000;

/// TESTNET ONLY: the TreasuryCap is shared so anyone can self-serve test
/// stablecoins (and the deployer can seed the lending reserve). UNLIMITED mint;
/// never ship to mainnet.
fun init(witness: USDY, ctx: &mut TxContext) {
    let (treasury, metadata) = coin::create_currency(
        witness,
        DECIMALS,
        b"USDY",
        b"FrostVault Dollar",
        b"Test USD stablecoin borrowed against collateral in FrostVault (testnet only).",
        option::none(),
        ctx,
    );
    transfer::public_freeze_object(metadata);
    transfer::public_share_object(treasury);
}

/// Self-serve faucet: mint the default drip to the caller.
entry fun faucet(treasury: &mut TreasuryCap<USDY>, ctx: &mut TxContext) {
    mint(treasury, FAUCET_AMOUNT, ctx.sender(), ctx)
}

/// Mint stablecoins to a recipient (faucet / reserve seeding).
public fun mint(
    treasury: &mut TreasuryCap<USDY>,
    amount: u64,
    recipient: address,
    ctx: &mut TxContext,
) {
    let c = coin::mint(treasury, amount, ctx);
    transfer::public_transfer(c, recipient);
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(USDY {}, ctx)
}
