#!/usr/bin/env bash
set -euo pipefail

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$HARNESS_DIR/versions.env"

WORKTREE_ROOT="$(git -C "$HARNESS_DIR" rev-parse --show-toplevel)"
COMMON_GIT_DIR="$(git -C "$WORKTREE_ROOT" rev-parse --git-common-dir)"
if [[ "$COMMON_GIT_DIR" != /* ]]; then
  COMMON_GIT_DIR="$WORKTREE_ROOT/$COMMON_GIT_DIR"
fi
PRIMARY_REPO_ROOT="$(cd "$(dirname "$COMMON_GIT_DIR")" && pwd)"

TOOL_CACHE="${ZOMBIE_BITE_TOOL_CACHE:-/tmp/polkadot-zombie-bite-tools}"
ZOMBIE_BITE_DIR="$TOOL_CACHE/zombie-bite"
ZOMBIE_BITE_BIN="$TOOL_CACHE/bin/zombie-bite"
DG_DIR="$TOOL_CACHE/dg"
GENERATED_DIR="$HARNESS_DIR/generated"
ARTIFACTS_DIR="${ZOMBIE_BITE_ARTIFACTS_DIR:-$HARNESS_DIR/artifacts-upgrade-paritydb}"
BULLETIN_SPEC="$GENERATED_DIR/bulletin-polkadot.json"

RUNTIMES_TARGET_DIR="${RUNTIMES_TARGET_DIR:-$PRIMARY_REPO_ROOT/target}"
ASSET_HUB_WASM="${ASSET_HUB_WASM:-$RUNTIMES_TARGET_DIR/release/wbuild/asset-hub-polkadot-runtime/asset_hub_polkadot_runtime.compact.compressed.wasm}"
PEOPLE_WASM="${PEOPLE_WASM:-$RUNTIMES_TARGET_DIR/release/wbuild/people-polkadot-runtime/people_polkadot_runtime.compact.compressed.wasm}"
BULLETIN_WASM="${BULLETIN_WASM:-$RUNTIMES_TARGET_DIR/release/wbuild/bulletin-polkadot-runtime/bulletin_polkadot_runtime.compact.compressed.wasm}"
PARACHAIN_NODE_BIN="${PARACHAIN_NODE_BIN:-$PRIMARY_REPO_ROOT/preview-net-v1/bin/polkadot-omni-node}"
COLLATOR_RUNTIME_LOG="${COLLATOR_RUNTIME_LOG:-aura=debug,runtime=debug,runtime::frame-support=debug,frame_support::migrations=info,runtime::indiv=debug,pallet-members-subscriber=debug,cumulus-consensus=debug,consensus::common=debug,parachain::collation-generation=debug,parachain::collator-protocol=debug,parachain=debug,xcm=debug}"

export HARNESS_DIR WORKTREE_ROOT PRIMARY_REPO_ROOT TOOL_CACHE ZOMBIE_BITE_DIR ZOMBIE_BITE_BIN DG_DIR
export GENERATED_DIR ARTIFACTS_DIR BULLETIN_SPEC RUNTIMES_TARGET_DIR
export ASSET_HUB_WASM PEOPLE_WASM BULLETIN_WASM
export PARACHAIN_NODE_BIN
export COLLATOR_RUNTIME_LOG
export RELAY_RPC ASSET_HUB_RPC PEOPLE_RPC BULLETIN_RPC
export BULLETIN_GENESIS_HASH
export ASSET_HUB_LIVE_SPEC_VERSION PEOPLE_LIVE_SPEC_VERSION CANDIDATE_SPEC_VERSION

require_file() {
  if [[ ! -f "$1" ]]; then
    echo "Missing required file: $1" >&2
    exit 1
  fi
}
