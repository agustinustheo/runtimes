#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

require_file "$ARTIFACTS_DIR/ports.json"
require_file "$ARTIFACTS_DIR/upgrade-baseline.json"
require_file "$ASSET_HUB_WASM"
require_file "$PEOPLE_WASM"

client_manifest="$HARNESS_DIR/upgrade-client/Cargo.toml"
cargo build --release --locked --manifest-path "$client_manifest"
client="$HARNESS_DIR/upgrade-client/target/release/polkadot-live-fork-upgrade"
require_file "$client"

recovery_arg=""
if [[ "${ZOMBIE_BITE_ALLOW_ALREADY_ACTIVE_CANDIDATES:-0}" == "1" ]]; then
  recovery_arg="--allow-already-active"
fi

asset_hub_pallet_args=()
for pallet in ${ASSET_HUB_EXPECTED_NEW_PALLETS:-}; do
  asset_hub_pallet_args+=(--expect-pallet "$pallet")
done
people_pallet_args=()
for pallet in ${PEOPLE_EXPECTED_NEW_PALLETS:-}; do
  people_pallet_args+=(--expect-pallet "$pallet")
done

asset_hub_port="$(node -p "require(process.argv[1]).para_1000_collator_port" "$ARTIFACTS_DIR/ports.json")"
people_port="$(node -p "require(process.argv[1]).para_1004_collator_port" "$ARTIFACTS_DIR/ports.json")"

"$client" \
  --rpc "ws://127.0.0.1:$asset_hub_port" \
  --wasm "$ASSET_HUB_WASM" \
  --expected-spec "$CANDIDATE_SPEC_VERSION" \
  --chain asset-hub \
  ${asset_hub_pallet_args[@]+"${asset_hub_pallet_args[@]}"} \
  ${recovery_arg:+"$recovery_arg"}

"$client" \
  --rpc "ws://127.0.0.1:$people_port" \
  --asset-hub-rpc "ws://127.0.0.1:$asset_hub_port" \
  --wasm "$PEOPLE_WASM" \
  --expected-spec "$CANDIDATE_SPEC_VERSION" \
  --chain people \
  ${people_pallet_args[@]+"${people_pallet_args[@]}"} \
  ${recovery_arg:+"$recovery_arg"}

echo "Asset Hub and People runtime upgrades completed in the required order."
