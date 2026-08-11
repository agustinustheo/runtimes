#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

individuality_dir="${INDIVIDUALITY_DIR:-$PRIMARY_REPO_ROOT/../individuality}"
dependency_link="$(dirname "$WORKTREE_ROOT")/individuality"
created_link=0

require_file "$individuality_dir/Cargo.toml"
if [[ -L "$dependency_link" ]]; then
  if [[ "$(cd "$dependency_link" && pwd -P)" != "$(cd "$individuality_dir" && pwd -P)" ]]; then
    echo "Unexpected Individuality symlink target: $dependency_link" >&2
    exit 1
  fi
elif [[ -e "$dependency_link" ]]; then
  echo "Refusing to replace existing path required by Cargo: $dependency_link" >&2
  exit 1
else
  ln -s "$individuality_dir" "$dependency_link"
  created_link=1
fi

cleanup() {
  if [[ "$created_link" == "1" ]] && [[ -L "$dependency_link" ]]; then
    unlink "$dependency_link"
  fi
}
trap cleanup EXIT

CARGO_TARGET_DIR="$RUNTIMES_TARGET_DIR" cargo build --release --locked \
  --manifest-path "$WORKTREE_ROOT/Cargo.toml" \
  -p asset-hub-polkadot-runtime \
  -p people-polkadot-runtime

require_file "$ASSET_HUB_WASM"
require_file "$PEOPLE_WASM"
echo "Built Asset Hub and People candidate runtimes at spec_version $CANDIDATE_SPEC_VERSION"
