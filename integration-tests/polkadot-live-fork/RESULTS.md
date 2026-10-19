# Live-fork upgrade results for polkadot-fellows/runtimes#1306

This file records the run of this harness against the #1306 head `e1171aac8`, with the test-only `spec_version` bump to `2005001`. The file is updated after each phase.

The #1320 run uses its own capture. A capture cannot be shared between the two candidates: Doppelganger writes the candidate's `System.AuthorizedUpgrade` into each parachain database at the end of the parachain sync, and the relay snapshot records the parachain heads of the same capture. Both runs share the tools, the node binaries, and the Cargo caches.

## Status

| Phase | Status | UTC |
|---|---|---|
| Candidate build | Passed | 2026-10-19 10:36 to 10:42 |
| Preflight (live RPCs) | Passed | 2026-10-19 12:41 |
| Capture (`make bite`) | Running | started 2026-10-19 12:41 |
| `make spawn` | Not started | |
| `make verify-fork` | Not started | |
| `make verify` | Not started | |
| `make upgrade` | Not started | |
| `make verify-upgrade` (900 s) | Not started | |
| `make inspect-runtime-logs` | Not started | |

## Candidate build

`cargo build --release --locked -p asset-hub-polkadot-runtime -p people-polkadot-runtime`, 6 jobs, separate target directory, 5 minutes 40 seconds.

| Candidate | `spec_version` | SHA-256 |
|---|---:|---|
| Asset Hub | `2005001` | `1fdef73481faedffe34705d1f8fc5e0eae92c767d673d4d3a5d15e3fa8580e13` |
| People | `2005001` | `bc048b3bc330132f762deb6bdbe8059196ea27df327873cd44a9d748703c5b3f` |

The `spec_version` values come from the `runtime_version` custom section of each decompressed WASM.

## Preflight

| Chain | Live block | `spec_version` |
|---|---:|---:|
| Relay | `33499521` | `2005000` |
| Asset Hub | `22024529` | `2005000` |
| People | `11163271` | `2005000` |
| Bulletin | `2306566` | `2005000` |

Bulletin genesis matched `BULLETIN_GENESIS_HASH`.

## Environment

- macOS arm64, 12 CPUs, 24 GiB memory.
- Node.js `v24.14.1`. The RPC scripts need the global `WebSocket`, which Node.js 20 does not have.
- `polkadot-omni-node` `1.24.1-8ae9775dc43` from `preview-net-v1/bin` (`polkadot-stable2606-1`).
- Zombie Bite `6d16648178ab` with `patches/zombie-bite-live-fork.patch`, Doppelganger `v0.2.1`.
