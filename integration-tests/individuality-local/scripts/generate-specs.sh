#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SPECS="$HERE/zombienet/specs"
mkdir -p "$SPECS"
cd "$ROOT"
FEATURES="fast-runtime,polkadot,people-polkadot,asset-hub-polkadot,bulletin-polkadot"
for chain in polkadot-local people-polkadot-local asset-hub-polkadot-local bulletin-polkadot-local; do
	output="$SPECS/$chain.raw.json"
	cargo run --release --locked -p chain-spec-generator --no-default-features --features "$FEATURES" -- "$chain" --raw > "$output"
	jq -e --arg expected_id "$chain" '.id == $expected_id and (.genesis.raw.top | type == "object")' "$output" >/dev/null
	case "$chain" in
		people-polkadot-local) expected_para_id=1004 ;;
		asset-hub-polkadot-local) expected_para_id=1000 ;;
		bulletin-polkadot-local) expected_para_id=1010 ;;
		*) continue ;;
	esac
	jq -e --argjson expected_para_id "$expected_para_id" \
		'.relay_chain == "polkadot-local" and .para_id == $expected_para_id' "$output" >/dev/null
done
echo "Wrote raw specs to $SPECS."
