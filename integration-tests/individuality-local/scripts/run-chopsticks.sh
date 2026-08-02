#!/usr/bin/env bash
set -eo pipefail
target="$1"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
if [ -z "${CHOPSTICKS_BIN:-}" ]; then
	CHOPSTICKS_BIN="/Users/theo/Projects/parity/individuality/e2e-tests/node_modules/.bin/chopsticks"
fi
[ -x "$CHOPSTICKS_BIN" ] || { echo "set CHOPSTICKS_BIN to a Chopsticks 1.5+ executable" >&2; exit 1; }
case "$target" in
	asset-hub)
		config="$HERE/chopsticks/asset-hub-polkadot.yaml"
		wasm="$ROOT/target/release/wbuild/asset-hub-polkadot-runtime/asset_hub_polkadot_runtime.compact.compressed.wasm"
		;;
	people)
		config="$HERE/chopsticks/people-polkadot.yaml"
		wasm="$ROOT/target/release/wbuild/people-polkadot-runtime/people_polkadot_runtime.compact.compressed.wasm"
		;;
	*) echo "usage: run-chopsticks.sh <asset-hub|people>" >&2; exit 2 ;;
esac
test -f "$wasm" || { echo "missing $wasm; run build-wasm.sh first" >&2; exit 1; }
mkdir -p "$HERE/chopsticks/output"
"$CHOPSTICKS_BIN" try-runtime --config "$config" --runtime "$wasm" --checks PreAndPost \
	--disable-spec-check 2>&1 | tee "$HERE/chopsticks/output/$target-try-runtime.log"
