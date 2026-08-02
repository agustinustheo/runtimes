#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"
cargo build --release -p people-polkadot-runtime -p asset-hub-polkadot-runtime -p bulletin-polkadot-runtime
echo "Built candidate WASM artifacts under $ROOT/target/release/wbuild."
