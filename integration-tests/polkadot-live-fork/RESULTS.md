# Live-fork upgrade results for polkadot-fellows/runtimes#1320

This file records the run of this harness against the #1320 head `e7d5d55aa`, with the test-only `spec_version` bump to `2005001`. The file is updated after each phase.

## Status

| Phase | Status | UTC |
|---|---|---|
| Candidate build | Passed | 2026-10-19 10:28 to 10:33 |
| Preflight (live RPCs) | Passed | 2026-10-19 10:35 |
| Capture (`make bite`) | Running | started 2026-10-19 10:36 |
| `make spawn` | Not started | |
| `make verify-fork` | Not started | |
| `make verify` | Not started | |
| `make upgrade` | Not started | |
| `make verify-upgrade` (900 s) | Not started | |
| `make inspect-runtime-logs` | Not started | |

## Candidate build

`cargo build --release --locked -p asset-hub-polkadot-runtime -p people-polkadot-runtime`, 8 jobs, 4 minutes 43 seconds (incremental Cargo cache).

| Candidate | `spec_version` | SHA-256 |
|---|---:|---|
| Asset Hub | `2005001` | `9183d3da4b77ac05925a822f9957e9f51c03e93b9b9f3aa0c203e52a9a4fa68f` |
| People | `2005001` | `2b804e45cbc5b15fb2c385ac6ef9d757f4d10e0156afd124be297dc3241698c8` |

The `spec_version` values come from the `runtime_version` custom section of each decompressed WASM.

## Preflight

| Chain | Live block | `spec_version` |
|---|---:|---:|
| Relay | `33498254` | `2005000` |
| Asset Hub | `22020812` | `2005000` |
| People | `11159543` | `2005000` |
| Bulletin | `2305303` | `2005000` |

Bulletin genesis matched `BULLETIN_GENESIS_HASH`.

## Environment

- macOS arm64, 12 CPUs, 24 GiB memory.
- Node.js `v24.14.1`. The RPC scripts need the global `WebSocket`, which Node.js 20 does not have.
- `polkadot-omni-node` `1.24.1-8ae9775dc43` from `preview-net-v1/bin` (`polkadot-stable2606-1`).
- Zombie Bite `6d16648178ab` with `patches/zombie-bite-live-fork.patch`, Doppelganger `v0.2.1`.
