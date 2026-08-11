#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
touch "$ARTIFACTS_DIR/stop.txt"
