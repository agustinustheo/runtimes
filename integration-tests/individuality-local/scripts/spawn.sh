#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
ZOMBIENET_DIR="${ZOMBIENET_DIR:-$(mktemp -d /tmp/individuality-zombienet.XXXXXX)}"

for spec in \
	"$HERE/zombienet/specs/polkadot-local.raw.json" \
	"$HERE/zombienet/specs/people-polkadot-local.raw.json" \
	"$HERE/zombienet/specs/asset-hub-polkadot-local.raw.json" \
	"$HERE/zombienet/specs/bulletin-polkadot-local.raw.json"; do
	test -s "$spec" || { echo "missing generated spec: $spec; run generate-specs.sh first" >&2; exit 1; }
done

for bin in polkadot polkadot-omni-node zombienet; do
	command -v "$bin" >/dev/null || { echo "$bin not found on PATH" >&2; exit 1; }
done

# This detects a node bundle older than the runtime's host-function imports before zombienet
# starts several long-lived processes.
cd "$HERE/zombienet"
polkadot-omni-node export-genesis-wasm --chain specs/people-polkadot-local.raw.json >/dev/null
echo "Zombienet state directory: $ZOMBIENET_DIR"
exec zombienet --provider native --dir "$ZOMBIENET_DIR" spawn network.toml
