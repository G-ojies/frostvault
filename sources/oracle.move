/// Price oracle abstraction for FrostVault.
///
/// Stores the USD price of 1 whole BTC, scaled by 1e6 (same scale as USDY),
/// e.g. $100,000.00 is stored as 100_000_000000.
///
/// For the testnet MVP the price is admin-pushed (via `OracleCap`) so a live
/// demo can crash the price on stage and trigger a liquidation. In production
/// `update_price` would be fed by a Pyth `PriceInfoObject` adapter — the rest
/// of the protocol consumes `price()` and is agnostic to the source.
module frostvault::oracle;

/// Capability authorizing price updates. Held by the deployer (or a Pyth adapter).
public struct OracleCap has key, store {
    id: UID,
}

/// Shared price feed read by the vault.
public struct PriceFeed has key {
    id: UID,
    /// USD price of 1 BTC, scaled by 1e6.
    price_6dec: u64,
    /// Tx-context epoch of the last update (lightweight staleness signal).
    last_update_epoch: u64,
}

const EZeroPrice: u64 = 0;

/// Initial price: $100,000.00 per BTC.
const INITIAL_PRICE: u64 = 100_000_000000;

fun init(ctx: &mut TxContext) {
    transfer::transfer(
        OracleCap { id: object::new(ctx) },
        ctx.sender(),
    );
    transfer::share_object(PriceFeed {
        id: object::new(ctx),
        price_6dec: INITIAL_PRICE,
        last_update_epoch: ctx.epoch(),
    });
}

/// Push a new price (admin / oracle adapter only).
public fun update_price(_: &OracleCap, feed: &mut PriceFeed, new_price: u64, ctx: &TxContext) {
    assert!(new_price > 0, EZeroPrice);
    feed.price_6dec = new_price;
    feed.last_update_epoch = ctx.epoch();
}

/// Current USD price of 1 BTC, scaled by 1e6.
public fun price(feed: &PriceFeed): u64 {
    feed.price_6dec
}

public fun last_update_epoch(feed: &PriceFeed): u64 {
    feed.last_update_epoch
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx)
}

#[test_only]
public fun new_feed_for_testing(price_6dec: u64, ctx: &mut TxContext): PriceFeed {
    PriceFeed { id: object::new(ctx), price_6dec, last_update_epoch: 0 }
}

#[test_only]
public fun new_cap_for_testing(ctx: &mut TxContext): OracleCap {
    OracleCap { id: object::new(ctx) }
}

#[test_only]
public fun destroy_feed_for_testing(feed: PriceFeed) {
    let PriceFeed { id, price_6dec: _, last_update_epoch: _ } = feed;
    object::delete(id);
}

#[test_only]
public fun destroy_cap_for_testing(cap: OracleCap) {
    let OracleCap { id } = cap;
    object::delete(id);
}
