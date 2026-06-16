#!/usr/bin/env bash
# Publish FrostVault to Sui testnet, capture the object IDs, seed the lending
# reserve, and write web/.env.local. Requires: sui CLI on testnet w/ gas, jq.
set -euo pipefail

cd "$(dirname "$0")/.."
PKG_DIR="$(pwd)"
GAS_BUDGET=300000000

echo "==> Active address / env:"
sui client active-address
sui client active-env

echo "==> Publishing package..."
OUT=$(sui client publish --gas-budget "$GAS_BUDGET" --json)

# Package ID
PACKAGE_ID=$(echo "$OUT" | jq -r '.objectChanges[] | select(.type=="published") | .packageId')

# Helper: find the first created object whose objectType ends with the suffix.
created_by_suffix() {
  echo "$OUT" | jq -r --arg sfx "$1" '
    .objectChanges[]
    | select(.type=="created")
    | select(.objectType | endswith($sfx))
    | .objectId' | head -1
}

BANK_ID=$(created_by_suffix "::vault::Bank")
PRICE_FEED_ID=$(created_by_suffix "::oracle::PriceFeed")
ADMIN_CAP_ID=$(created_by_suffix "::vault::AdminCap")
ORACLE_CAP_ID=$(created_by_suffix "::oracle::OracleCap")
# TreasuryCaps are generic: TreasuryCap<...::wbtc::WBTC>
WBTC_TREASURY_ID=$(echo "$OUT" | jq -r '.objectChanges[] | select(.type=="created") | select(.objectType | contains("::wbtc::WBTC")) | select(.objectType | contains("TreasuryCap")) | .objectId' | head -1)
USDY_TREASURY_ID=$(echo "$OUT" | jq -r '.objectChanges[] | select(.type=="created") | select(.objectType | contains("::usdy::USDY")) | select(.objectType | contains("TreasuryCap")) | .objectId' | head -1)

echo "PACKAGE_ID=$PACKAGE_ID"
echo "BANK_ID=$BANK_ID"
echo "PRICE_FEED_ID=$PRICE_FEED_ID"
echo "ADMIN_CAP_ID=$ADMIN_CAP_ID"
echo "ORACLE_CAP_ID=$ORACLE_CAP_ID"
echo "WBTC_TREASURY_ID=$WBTC_TREASURY_ID"
echo "USDY_TREASURY_ID=$USDY_TREASURY_ID"

echo "==> Seeding the lending reserve with 2,000,000 USDY..."
# Mint USDY to ourselves (2,000,000 * 1e6), then seed_reserve.
ME=$(sui client active-address)
sui client call --package "$PACKAGE_ID" --module usdy --function mint \
  --args "$USDY_TREASURY_ID" 2000000000000 "$ME" \
  --gas-budget "$GAS_BUDGET" >/dev/null

# Grab a USDY coin object we just minted.
USDY_COIN=$(sui client objects --json | jq -r --arg t "${PACKAGE_ID}::usdy::USDY" \
  '.[] | select(.data.type=="0x2::coin::Coin<\($t)>") | .data.objectId' | head -1)
echo "Seeding with USDY coin: $USDY_COIN"
sui client call --package "$PACKAGE_ID" --module vault --function seed_reserve \
  --args "$ADMIN_CAP_ID" "$BANK_ID" "$USDY_COIN" \
  --gas-budget "$GAS_BUDGET" >/dev/null

echo "==> Writing web/.env.local and deploy.local.json..."
cat > web/.env.local <<EOF
NEXT_PUBLIC_NETWORK=testnet
NEXT_PUBLIC_PACKAGE_ID=$PACKAGE_ID
NEXT_PUBLIC_BANK_ID=$BANK_ID
NEXT_PUBLIC_PRICE_FEED_ID=$PRICE_FEED_ID
NEXT_PUBLIC_WBTC_TREASURY_ID=$WBTC_TREASURY_ID
NEXT_PUBLIC_USDY_TREASURY_ID=$USDY_TREASURY_ID
NEXT_PUBLIC_ORACLE_CAP_ID=$ORACLE_CAP_ID
EOF

cat > deploy.local.json <<EOF
{
  "network": "testnet",
  "packageId": "$PACKAGE_ID",
  "bankId": "$BANK_ID",
  "priceFeedId": "$PRICE_FEED_ID",
  "adminCapId": "$ADMIN_CAP_ID",
  "oracleCapId": "$ORACLE_CAP_ID",
  "wbtcTreasuryId": "$WBTC_TREASURY_ID",
  "usdyTreasuryId": "$USDY_TREASURY_ID"
}
EOF

echo "==> Done. IDs written to web/.env.local + deploy.local.json"
