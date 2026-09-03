#!/usr/bin/env bash
set -euo pipefail

wrapper_dir="$(cd "$(dirname "$0")" && pwd)"
real_doppelganger="${ZOMBIE_BITE_REAL_DOPPELGANGER:-}"
local_relay_spec="${ZOMBIE_BITE_LOCAL_RELAY_SPEC:-}"
if [[ -z "$real_doppelganger" && -f "$wrapper_dir/real-doppelganger-path" ]]; then
	real_doppelganger="$(<"$wrapper_dir/real-doppelganger-path")"
fi
if [[ -z "$local_relay_spec" && -f "$wrapper_dir/local-relay-spec-path" ]]; then
	local_relay_spec="$(<"$wrapper_dir/local-relay-spec-path")"
fi
: "${real_doppelganger:?set ZOMBIE_BITE_REAL_DOPPELGANGER or create real-doppelganger-path beside this wrapper}"
: "${local_relay_spec:?set ZOMBIE_BITE_LOCAL_RELAY_SPEC or create local-relay-spec-path beside this wrapper}"

args=("$@")
is_sync=0
for arg in "${args[@]}"; do
	if [[ "$arg" == "--sync" ]]; then
		is_sync=1
		break
	fi
done

if (( is_sync )); then
	for ((index = 0; index + 1 < ${#args[@]}; index++)); do
		if [[ "${args[index]}" == "--chain" && "${args[index + 1]}" == "polkadot" ]]; then
			args[index + 1]="$local_relay_spec"
			break
		fi
	done
fi

exec "$real_doppelganger" "${args[@]}"
