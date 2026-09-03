#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

CARGO_TARGET_DIR="$RUNTIMES_TARGET_DIR" cargo build --release --locked \
  --manifest-path "$WORKTREE_ROOT/Cargo.toml" \
  -p asset-hub-polkadot-runtime \
  -p people-polkadot-runtime

require_file "$ASSET_HUB_WASM"
require_file "$PEOPLE_WASM"
echo "Built Asset Hub and People candidate runtimes at spec_version $CANDIDATE_SPEC_VERSION"
