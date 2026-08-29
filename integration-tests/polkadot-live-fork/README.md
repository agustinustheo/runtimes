# Polkadot live-state runtime upgrades with Zombie Bite

This harness captures the live state of the Polkadot Relay chain, Asset Hub (1000), People (1004), and Bulletin (1010). The harness starts all four chains with their captured production runtimes. The harness then applies the runtime candidates that you build from this checkout.

PR #1233 requires two upgrades in this order:

1. Asset Hub, so that the PGAS asset and the Asset Hub side of the Individuality protocol exist.
2. People, so that the People pallets and the notifier can send to Asset Hub after its upgrade.

The harness intentionally does not upgrade the Relay chain and Bulletin. Bulletin's current live runtime does not contain `pallet-transaction-storage`. Thus People-to-Bulletin long-term storage cannot succeed until a future upgrade of the Bulletin runtime supplies that receiver. The harness does not claim that this unavailable flow works.

The file `versions.env` pins Zombie Bite and Doppelganger. The pinned patch adds the multi-parachain live-fork support that this harness needs. After the capture node imports the target block, the patch lets the ParityDB writes settle. The patch then stops the capture node. The patch reopens the database to replay the pending logs. The patch then verifies the pruning metadata. The patch makes a snapshot of the database only after these steps. The patch also imports candidate-specific `System.AuthorizedUpgrade` values. The patch fetches the exact live People-to-Asset-Hub HRMP channel and MQC head that the targeted XCM scenario requires. The patch keeps this channel and head. The patch also tolerates the initial metrics window during spawn. Git ignores the generated state, the chain specs, and the logs.

The default database is pruned ParityDB. This configuration prevents the oversized RocksDB pruning-journal failure that occurs on macOS. This configuration also keeps the captured current state that the upgrades need.

For the test design, measured timing, and recorded results, see
[TEST_PROCEDURE.md](TEST_PROCEDURE.md). For copyable commands and shortened output samples, see
[COMMANDS_AND_EXPECTED_OUTPUT.md](COMMANDS_AND_EXPECTED_OUTPUT.md). The detailed recovery and patch
notes remain in [RUNBOOK.md](RUNBOOK.md).

## Run the complete lifecycle

Build the two candidate WASMs first. Both candidates must use a `spec_version` that is higher than the captured live versions.

```sh
cd integration-tests/polkadot-live-fork
CARGO_BUILD_JOBS=2 make build-wasm
CARGO_BUILD_JOBS=2 make bite
make spawn
```

Do not stop `make spawn`. Run these commands in a different shell:

```sh
make verify-fork
make verify
make mark-runtime-logs
CARGO_BUILD_JOBS=2 make upgrade
make verify-upgrade
make inspect-runtime-logs
make stop
```

The default runtime artifacts come from `target/release/wbuild` in the primary runtimes checkout. If it is necessary, override `RUNTIMES_TARGET_DIR`, `ASSET_HUB_WASM`, or `PEOPLE_WASM`. The default RPC ports are Relay `9944`, Asset Hub `9910`, People `9914`, and Bulletin `9920`. The harness records the actual ports in `artifacts-upgrade-paritydb/ports.json`.

## What each phase proves

`make verify-fork` makes an independent check of the live provenance at the captured boundary. The local header must match the block number, parent hash, extrinsics root, and consensus digest of the configured live RPC. The boundary block hash and the state root can differ because Zombie Bite installs local authority and narrowly scoped test storage.

`make verify` runs before the upgrades. The command proves that:

- the Relay chain state contains registrations for all three parachains;
- Asset Hub and People still run the captured live runtime code and live `spec_version`, not the candidates;
- both chains contain an authorization for their exact candidate code hash;
- the local Relay chain keeps the live People-to-Asset-Hub HRMP channel and MQC head that the scenario uses;
- the pending People-to-Asset-Hub notifier fixture is present; and
- the Relay chain, Asset Hub, People, and Bulletin all advance.

The notifier fixture represents the governance subscription that the production rollout must create. The harness writes the fixture under storage prefixes that do not exist in the captured People runtime. The fixture becomes readable only after the chain enacts the People candidate. The fixture does not give root to an account, and it does not bypass XCM execution.

`make upgrade` submits unsigned `System.apply_authorized_upgrade` extrinsics, first on Asset Hub and then on People. FRAME checks the pre-authorized code hash and version before it routes the code through the parachain runtime-upgrade path. The upgrade client then checks that:

- the exact candidate code and `spec_version` became active;
- Asset Hub created the PGAS asset `2_000_000_000` and did not change `Assets.NextAssetId`;
- the Revive v4 multi-block migration completed, and the runtime records it as historic; and
- after the People upgrade, the notifier's authorized maintenance call sends a real XCM that activates `MembersSubscriber` on Asset Hub.

`make verify-upgrade` makes an independent check that proves three facts. The upgrades consumed both authorizations. The Relay chain code and the Bulletin code did not change. All four chains continue to produce blocks throughout a 15-minute observation. `make mark-runtime-logs` and `make inspect-runtime-logs` isolate the Asset Hub and People runtime, migration, and Individuality messages written during and after the upgrades for manual review.

This harness gives evidence of live-state upgrades and of targeted cross-chain operation. The harness does not replace the execution of production governance, compatibility tests with external clients, or the later Bulletin receiver upgrade.

## Latest validated run

The latest validation completed on 2026-08-29 UTC from PR #2 commit
`72aeee6e54c1f2357b8b2dbab44ce1dd2316d6e0`. That commit contains the signed PR #1 merge
`bb7e123b7c5994fa73330556e53e7d88a306572e`, which contains PR #1233 at
`1a5410be8244b00fbcec68a5efc54b186220c5c5`. The local node binaries matched the published macOS
ARM64 checksums for Polkadot SDK `polkadot-stable2606-1`; both reported
`1.24.1-8ae9775dc43`.

Both artifact-reuse variables were explicitly unset. A new four-chain production capture took 2
hours 45 minutes 49 seconds and produced `ready.json` plus four non-empty, gzip-valid snapshots.
The recorded boundaries were Relay `32766531`, Asset Hub `20018213`, People `9130240`, and Bulletin
`1579329`. Their captured runtime versions were `2003002`, `2003002`, `2003002`, and `2002001`.

The exact candidates activated in the run were:

| Candidate | `spec_version` | SHA-256 |
|---|---:|---|
| Asset Hub | `2004000` | `e0f27398eccd5f2074943c6526ce633adeee816c50f27ea6032937502f70c80d` |
| People | `2004000` | `93badb05d46b54cbbbacc4475dbf7da74058014ac6ba15d6b5511803f451d1e6` |

Asset Hub upgraded before People. Its PGAS, `NextAssetId`, and Revive migration checks passed before
the People upgrade was submitted. The strict invocation activated both exact candidates but then
exposed a stale harness assertion that still required the intentionally removed `Honour` pallet.
The assertion was corrected to require the current pallet set and reject `Honour`; formatting and
locked release checks passed. The documented explicit recovery invocation then verified both
already-active code blobs, completed the People-to-Asset-Hub initialization XCM, confirmed the Asset
Hub subscription, and exited successfully without resubmitting either upgrade. The independent
verifier confirmed the exact candidate bytes, consumed authorizations, and unchanged Relay and
Bulletin code.

The full, unmodified 900-second verifier passed. All 15 one-minute samples advanced. Relay advanced
`32766671 -> 32766821` (+150), Asset Hub `20018605 -> 20019055` (+450), People
`9130635 -> 9131085` (+450), and Bulletin `1579466 -> 1579616` (+150). The post-checkpoint logs
showed XcmpQueue migration from version 6 to 7 on both upgraded chains, Asset Hub's `PGAS asset
created`, People's `lite people collection created`, the notifier whitelisting parachain `1000`,
and its offchain worker successfully submitting `send_init_page`. There were zero post-checkpoint
error, panic, failed-migration, runtime-trap, fatal, or essential-task-failure lines.

The clean candidate build took 13 minutes 53 seconds with two jobs and the repository-root workspace
hint. Spawn reached `network is up and running` in 51 seconds. The strict invocation ran for 8
minutes through both activations before the stale assertion; the successful recovery checks took 9
seconds. The post-upgrade verifier took exactly 900 seconds, and the foreground spawner exited 21
seconds after `make stop`. The network stopped cleanly with zero related processes and zero captured
port listeners remaining. Results remain local and untracked in
`integration-tests/polkadot-live-fork/artifacts-clean-proof-stable2606-20260829-001`. The retained
artifact uses 26 GiB. After preserving both candidate WASMs in that artifact and cleaning this run's
Cargo targets, 250 GiB remained free.
