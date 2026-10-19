# Live-fork upgrade results for polkadot-fellows/runtimes#1320

This file records the run of this harness against the #1320 head `e7d5d55aa`, with the test-only `spec_version` bump to `2005001`. The file is updated after each phase.

## Status

| Phase | Status | UTC |
|---|---|---|
| Candidate build | Passed | 2026-10-19 10:28 to 10:33 |
| Preflight (live RPCs) | Passed | 2026-10-19 10:35 |
| Capture (`make bite`) | Passed | 2026-10-19 10:33 to 12:15 (1 h 41 min) |
| `make spawn` | Passed, network up in 50 s | 2026-10-19 12:15 |
| `make verify-fork` | Passed | 2026-10-19 12:16 |
| `make verify` | Passed | 2026-10-19 12:17 |
| `make upgrade` | Passed | 2026-10-19 12:17 to 12:24 (6 min 43 s) |
| `make verify-upgrade` (900 s) | Passed | 2026-10-19 12:24 to 12:39 |
| `make inspect-runtime-logs` | Passed, no errors | 2026-10-19 12:39 |
| `make stop` | Passed, clean shutdown in 40 s | 2026-10-19 12:40 |

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

## Capture

A fresh production capture with both artifact-reuse variables unset. The bite log contains no `ERROR`, panic, or failed step.

| Chain | Boundary block | Captured `spec_version` |
|---|---:|---:|
| Relay | `33499231` | `2005000` |
| Asset Hub | `22020812` | `2005000` |
| People | `11159542` | `2005000` |
| Bulletin | `2305302` | `2005000` |

The retained artifact uses 2.8 GiB.

## Fork provenance (`make verify-fork`)

All four local chains keep the live block number, parent hash, extrinsics root, and consensus digest at the boundary. The state roots differ, as expected for the authority and test-storage overrides.

| Chain | Live canonical hash | Canonical parent |
|---|---|---|
| Relay | `0x60ec7941b46d204b30a7278bbe5ba27738e9233891cbe879049c0d0ac1e504f6` | `0xf557e6c6c157ebc731d5fd213bea04b216942afb4fb683afa7094191c1cfe112` |
| Asset Hub | `0x390b9ccc05c600bb82f6e85ec391908f285a923679b6c559ac3c8bd926bba047` | `0x6f19ba1609f43acebb5c19c251c4755280e40de0dba4885f3b684e2a590d0dde` |
| People | `0xec4ef79e4abe9cb823e5bb6bea26e48fa6368ff97f05292d8e3b811543e8e2d1` | `0xfc6979ea15102201c1b7e673567ef87f27dd1bd07a77204d511905d7a4864c27` |
| Bulletin | `0x7b66b54ff10125d8666ccf04a287b5b10a9119695be239d8a100717c6870ce36` | `0x9414c2da0cf46ca0af96030f61599195aaf780c0e48fae8c045ee607faac2eeb` |

## Pre-upgrade checks (`make verify`)

- The relay registers parachains `1000`, `1004`, and `1010`.
- The relay keeps the live People-to-Asset-Hub HRMP head `0x6f114d344384a3f6d6dc2a1d3dccf44b456b17bd83e849086661f13c7cdd4048`.
- Asset Hub and People run the captured `2005000` runtimes, and both contain the candidate authorization.
- The captured People runtime already completed the Asset Hub notifier initialization before the upgrade. This is the expected result now that `MembersNotifier` is live.
- All four chains advanced in 24 seconds: Relay +4, Asset Hub +12, People +12, Bulletin +4.

## Upgrade (`make upgrade`)

1. Asset Hub: unsigned `System.apply_authorized_upgrade` finalized, `2005000` to `2005001`. After enactment: PGAS `49_999_999` exists, `Assets.NextAssetId` did not change, and no multi-block migration is in progress.
2. People: unsigned `System.apply_authorized_upgrade` finalized, `2005000` to `2005001`. After enactment: the Individuality pallet set is in the metadata.
3. The People-to-Asset-Hub subscription is active on both chains after the People upgrade.

## Post-upgrade observation (`make verify-upgrade`)

- Asset Hub and People run the exact candidate bytes at `2005001`. Both `System.AuthorizedUpgrade` values were consumed.
- Relay and Bulletin code did not change (`2005000`).
- All 15 one-minute samples advanced on all four chains:

| Chain | Start | End | Blocks |
|---|---:|---:|---:|
| Relay | `33499320` | `33499470` | +150 |
| Asset Hub | `22021052` | `22021499` | +447 |
| People | `11159790` | `11160229` | +439 |
| Bulletin | `2305387` | `2305537` | +150 |

## Runtime logs (`make inspect-runtime-logs`)

Post-checkpoint lines: Asset Hub 152, People 43. Zero `ERROR`, panic, failed-migration, or essential-task lines.

- Asset Hub ran `on_runtime_upgrade` (logged twice, at block import and at re-execution). `RemoveAhMigratorPallet` and `RemoveStateTrieMigrationPallet` removed 0 keys. There is no migration for `MembersSubscriber`, `Pgas`, or `PgasAllowance`.
- People: `lite people collection already exists; skipping`. There is no migration for the Individuality pallets.
- Both chains log `WARN` lines saying that some `VersionedMigration`s can be removed because on-chain storage is already at the target version: `XcmpQueue` 5->6 and 6->7 (both chains), and `Staking` 17->18 and `Dap` 1->2 (Asset Hub). These migrations are in `Unreleased` on `main` too. They are a possible cleanup, not a #1320 problem.

## Result

**Passed.** The #1320 Asset Hub and People runtimes upgrade from the live `2005000` state, the People-to-Asset-Hub subscription stays active, and all four chains keep producing blocks for 15 minutes after the upgrades.

## Environment

- macOS arm64, 12 CPUs, 24 GiB memory.
- Node.js `v24.14.1`. The RPC scripts need the global `WebSocket`, which Node.js 20 does not have.
- `polkadot-omni-node` `1.24.1-8ae9775dc43` from `preview-net-v1/bin` (`polkadot-stable2606-1`).
- Zombie Bite `6d16648178ab` with `patches/zombie-bite-live-fork.patch`, Doppelganger `v0.2.1`.
