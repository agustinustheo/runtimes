#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

"$HARNESS_DIR/scripts/setup.sh"
require_file "$ASSET_HUB_WASM"
require_file "$PEOPLE_WASM"
require_file "$BULLETIN_WASM"

node "$HARNESS_DIR/scripts/preflight.mjs"
config="$(node "$HARNESS_DIR/scripts/generate-config.mjs")"

export PATH="$DG_DIR:$PATH"
export ZOMBIE_BITE_STATE_PRUNING="${ZOMBIE_BITE_STATE_PRUNING:-256}"
export ZOMBIE_BITE_PARA_1000_STATE_PRUNING="${ZOMBIE_BITE_PARA_1000_STATE_PRUNING:-archive-canonical}"
export ZOMBIE_BITE_RC_PORT="${ZOMBIE_BITE_RC_PORT:-9944}"
export ZOMBIE_BITE_BOB_PORT="${ZOMBIE_BITE_BOB_PORT:-9945}"
export ZOMBIE_BITE_PARA_1000_PORT="${ZOMBIE_BITE_PARA_1000_PORT:-9910}"
export ZOMBIE_BITE_PARA_1004_PORT="${ZOMBIE_BITE_PARA_1004_PORT:-9914}"
export ZOMBIE_BITE_PARA_1010_PORT="${ZOMBIE_BITE_PARA_1010_PORT:-9920}"
export ZOMBIE_BITE_REUSE_PARA_ARTIFACTS=1
"$ZOMBIE_BITE_BIN" bite --config "$config" --database rocksdb

if [[ "${ZOMBIE_BITE_KEEP_DEBUG:-0}" != "1" ]] && [[ -d "$ARTIFACTS_DIR/bite-debug" ]]; then
  find "$ARTIFACTS_DIR/bite-debug" -depth -delete
fi
