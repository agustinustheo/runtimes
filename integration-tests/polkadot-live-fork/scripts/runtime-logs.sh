#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

checkpoint="$ARTIFACTS_DIR/runtime-log-checkpoint.txt"
output="$ARTIFACTS_DIR/runtime-upgrade-logs.txt"
pattern='runtime::frame-support|frame_support::migrations|runtime::indiv|pallet-members-subscriber|Runtime upgrade|runtime upgrade| ERROR |panic|failed migration|essential task'

latest_log() {
  local collator="$1"
  local latest=""
  local candidate
  shopt -s nullglob
  for candidate in "$ARTIFACTS_DIR"/spawn*/"$collator"/"$collator.log"; do
    if [[ -z "$latest" || "$candidate" -nt "$latest" ]]; then
      latest="$candidate"
    fi
  done
  shopt -u nullglob
  if [[ -z "$latest" ]]; then
    echo "Missing $collator log under $ARTIFACTS_DIR" >&2
    exit 1
  fi
  printf '%s\n' "$latest"
}

case "${1:-}" in
  mark)
    : > "$checkpoint"
    for collator in Collator-1000 Collator-1004; do
      log="$(latest_log "$collator")"
      printf '%s\t%s\t%s\n' "$collator" "$log" "$(wc -l < "$log" | tr -d ' ')" >> "$checkpoint"
      echo "$collator: marked $log"
    done
    ;;
  inspect)
    require_file "$checkpoint"
    : > "$output"
    while IFS=$'\t' read -r collator log line_count; do
      require_file "$log"
      current_log="$(latest_log "$collator")"
      if [[ "$current_log" != "$log" ]]; then
        echo "$collator log changed since the checkpoint: $log -> $current_log" >&2
        exit 1
      fi
      start_line=$((line_count + 1))
      printf '=== %s post-upgrade runtime logs ===\n' "$collator" | tee -a "$output"
      matches="$(tail -n "+$start_line" "$log" | grep -E "$pattern" || true)"
      if [[ -z "$matches" ]]; then
        echo "$collator: no post-upgrade runtime or migration logs matched" >&2
        exit 1
      fi
      printf '%s\n' "$matches" | tee -a "$output"
    done < "$checkpoint"
    echo "Review the Asset Hub and People excerpts above; saved to $output"
    ;;
  *)
    echo "usage: $0 mark|inspect" >&2
    exit 2
    ;;
esac
