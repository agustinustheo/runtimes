#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

require_file "$ARTIFACTS_DIR/bite/config.toml"
node "$HARNESS_DIR/scripts/configure-runtime-logs.mjs" "$ARTIFACTS_DIR/bite/config.toml"
export PATH="$DG_DIR:$PATH"
export ZOMBIE_BITE_STATE_PRUNING="${ZOMBIE_BITE_STATE_PRUNING:-256}"
export ZOMBIE_BITE_PARA_1000_STATE_PRUNING="${ZOMBIE_BITE_PARA_1000_STATE_PRUNING:-256}"
export ZOMBIE_BITE_RC_PORT="${ZOMBIE_BITE_RC_PORT:-9944}"
export ZOMBIE_BITE_BOB_PORT="${ZOMBIE_BITE_BOB_PORT:-9945}"
export ZOMBIE_BITE_PARA_1000_PORT="${ZOMBIE_BITE_PARA_1000_PORT:-9910}"
export ZOMBIE_BITE_PARA_1004_PORT="${ZOMBIE_BITE_PARA_1004_PORT:-9914}"
export ZOMBIE_BITE_PARA_1010_PORT="${ZOMBIE_BITE_PARA_1010_PORT:-9920}"

exec "$ZOMBIE_BITE_BIN" spawn --base-path "$ARTIFACTS_DIR" --with-monitor
