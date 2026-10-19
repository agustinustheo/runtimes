# Live-fork upgrade results for polkadot-fellows/runtimes#1306

This file records the run of this harness against the #1306 head `e1171aac8`, with the test-only `spec_version` bump to `2005001`. The file is updated after each phase.

The #1320 run uses its own capture. A capture cannot be shared between the two candidates: Doppelganger writes the candidate's `System.AuthorizedUpgrade` into each parachain database at the end of the parachain sync, and the relay snapshot records the parachain heads of the same capture. Both runs share the tools, the node binaries, and the Cargo caches.

## Status

| Phase | Status | UTC |
|---|---|---|
| Candidate build | Passed | 2026-10-19 10:36 to 10:42 |
| Preflight (live RPCs) | Passed | 2026-10-19 12:41 |
| Capture (`make bite`) | Passed | 2026-10-19 12:40 to 13:13 (33 min) |
| `make spawn` | Passed, network up in 48 s | 2026-10-19 13:14 |
| `make verify-fork` | Passed | 2026-10-19 13:15 |
| `make verify` | Passed on the second run (see below) | 2026-10-19 13:16 |
| `make upgrade` | Passed | 2026-10-19 13:16 to 13:23 (7 min 12 s) |
| `make verify-upgrade` (900 s) | Passed | 2026-10-19 13:23 to 13:38 |
| `make inspect-runtime-logs` | Passed, no errors | 2026-10-19 13:38 |
| `make stop` | Passed, clean shutdown | 2026-10-19 13:39 |

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

## Capture

A fresh production capture with both artifact-reuse variables unset. The bite log contains no `ERROR`, panic, or failed step.

| Chain | Boundary block | Captured `spec_version` |
|---|---:|---:|
| Relay | `33499744` | `2005000` |
| Asset Hub | `22024516` | `2005000` |
| People | `11163258` | `2005000` |
| Bulletin | `2306561` | `2005000` |

## Fork provenance (`make verify-fork`)

All four local chains keep the live block number, parent hash, extrinsics root, and consensus digest at the boundary.

| Chain | Live canonical hash | Canonical parent |
|---|---|---|
| Relay | `0x28e506f711f8e024f366443430df8a8caf41cc907c1edfc686fb0b9157a02455` | `0x13afbba9d4ce2712b276adffe95bdd375bc428ed8a90a93b2517ea36a4ccacf4` |
| Asset Hub | `0x930fe0a4a5efa086564ccaaf735719bcab1dacb6cce5934e98dc1557d5d730da` | `0x9a664ad339362de42d7b6218277b941893ee556ac2222ff04e8ba1c7faf7095f` |
| People | `0xdb66c0df5cd08f3754c03ad3957a163e184eeeb221ffaee5a6e170dbab606362` | `0x8882ef4788db378d5c54d6372fac1d3491dbf3810776435c1c9e2d443bc11e41` |
| Bulletin | `0x89d7a1e66ddaeb6946e041bf77c5fb435f76e40d49e5eac6c7bac7885ca0b4b0` | `0x8568543518211e689fff7d3a0ce29786583f02255edfb90c1f4bbdfada2de4b3` |

## Pre-upgrade checks (`make verify`)

The first run failed with `relay HRMP channel head does not match Asset Hub's captured MQC head`. This was a race in the harness, not a candidate problem. The captured People runtime sent the notifier initialization XCM right after spawn. The relay channel head moved (one 101-byte message), and `make verify` read it before Asset Hub processed the message. A few seconds later, both heads were `0x81a8f5f9c08ccf0ef0c95344343544619949d14eae245419ea31df26b7d34769`. The harness now polls for up to two minutes until the heads agree (commit `test: wait for the People-to-Asset-Hub HRMP head to settle`).

The second run passed:

- The relay registers parachains `1000`, `1004`, and `1010`, and keeps the People-to-Asset-Hub HRMP head `0x81a8f5f9…34769`.
- Asset Hub and People run the captured `2005000` runtimes, and both contain the candidate authorization.
- The captured People runtime already completed the Asset Hub notifier initialization.
- All four chains advanced in 24 seconds: Relay +4, Asset Hub +12, People +12, Bulletin +4.

## Upgrade (`make upgrade`)

1. Asset Hub: unsigned `System.apply_authorized_upgrade` finalized, `2005000` to `2005001`. After enactment: PGAS `49_999_999` exists, `Assets.NextAssetId` did not change, no multi-block migration is in progress, and `NftClaims` and `Scarcity` are in the metadata.
2. People: unsigned `System.apply_authorized_upgrade` finalized, `2005000` to `2005001`. After enactment: the Individuality pallet set and `Game`, `Score`, `NftCredits`, `Airdrop`, and `PeopleAirdrops` are in the metadata.
3. The People-to-Asset-Hub subscription is active on both chains after the People upgrade.

## Post-upgrade observation (`make verify-upgrade`)

- Asset Hub and People run the exact candidate bytes at `2005001`. Both `System.AuthorizedUpgrade` values were consumed.
- Relay and Bulletin code did not change (`2005000`).
- All 15 one-minute samples advanced on all four chains:

| Chain | Start | End | Blocks |
|---|---:|---:|---:|
| Relay | `33499835` | `33499985` | +150 |
| Asset Hub | `22024764` | `22025214` | +450 |
| People | `11163514` | `11163958` | +444 |
| Bulletin | `2306648` | `2306798` | +150 |

## Runtime logs (`make inspect-runtime-logs`)

Post-checkpoint lines: Asset Hub 160, People 106. Zero `ERROR`, panic, failed-migration, or essential-task lines. Each upgrade message is logged twice (block import and re-execution).

- FRAME initialized the storage version of each new pallet:
  - Asset Hub: `NftClaims` to `StorageVersion(1)`, `Scarcity` to `StorageVersion(2)`.
  - People: `NftCredits` to `StorageVersion(1)`. `Game`, `Score`, `Airdrop`, and `PeopleAirdrops` have no defined storage version, so FRAME set `StorageVersion(0)`.
- People: `lite people collection already exists; skipping`.
- Asset Hub: `RemoveAhMigratorPallet` and `RemoveStateTrieMigrationPallet` removed 0 keys.
- The same `WARN` lines as in the #1320 run: `VersionedMigration`s that already ran on chain (`XcmpQueue` 5->6 and 6->7, `Staking` 17->18, `Dap` 1->2). These are also in `main`, so they are not a #1306 problem.

## Result

**Passed.** The #1306 Asset Hub and People runtimes upgrade from the live `2005000` state. The seven new pallets are in the metadata and get their storage versions, the People-to-Asset-Hub subscription stays active, and all four chains keep producing blocks for 15 minutes after the upgrades.

## Environment

- macOS arm64, 12 CPUs, 24 GiB memory.
- Node.js `v24.14.1`. The RPC scripts need the global `WebSocket`, which Node.js 20 does not have.
- `polkadot-omni-node` `1.24.1-8ae9775dc43` from `preview-net-v1/bin` (`polkadot-stable2606-1`).
- Zombie Bite `6d16648178ab` with `patches/zombie-bite-live-fork.patch`, Doppelganger `v0.2.1`.
