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

The latest validation completed on 2026-08-30 UTC from PR #2 commit
`d8a48ef6af14465a734cbd099ba9bc8e6e0d727c`. That commit contains the signed PR #1 merge
`5b1652923abe49a21dba21ad352f9580dee56e2e`, which contains PR #1233 at
`a72ba8b15a046f28d10b1052860671da4ec13d37`. The local node binaries matched the published macOS
ARM64 checksums for Polkadot SDK `polkadot-stable2606-1`; both reported
`1.24.1-8ae9775dc43`.

Both artifact-reuse variables were explicitly unset. A new four-chain production capture took 3
hours 54 minutes 39 seconds and produced `ready.json` plus four non-empty, gzip-valid snapshots.
The recorded boundaries were Relay `32776366`, Asset Hub `20043704`, People `9155490`, and Bulletin
`1588607`. Their captured runtime versions were `2003002`, `2003002`, `2003002`, and `2002001`.

The exact candidates activated in the run were:

| Candidate | `spec_version` | SHA-256 |
|---|---:|---|
| Asset Hub | `2004000` | `e0f27398eccd5f2074943c6526ce633adeee816c50f27ea6032937502f70c80d` |
| People | `2004000` | `bc147e251052eb6ba566dda20297a640aa1f451dfcf94e2546d86179026ff13a` |

Asset Hub upgraded before People. Its PGAS, `NextAssetId`, and Revive migration checks passed before
the People upgrade was submitted. The single strict invocation, with recovery mode unset, activated
both exact candidates, verified the current People pallet set, completed the People-to-Asset-Hub
initialization XCM, confirmed the Asset Hub subscription, and exited successfully. The independent
verifier confirmed the exact candidate bytes, consumed authorizations, and unchanged Relay and
Bulletin code.

The full, unmodified 900-second verifier passed. All 15 one-minute samples advanced. Relay advanced
`32776473 -> 32776623` (+150), Asset Hub `20043991 -> 20044441` (+450), People
`9155788 -> 9156238` (+450), and Bulletin `1588711 -> 1588861` (+150). The post-checkpoint logs
showed XcmpQueue migration from version 6 to 7 on both upgraded chains, Asset Hub's `PGAS asset
created`, People's `lite people collection created`, the notifier whitelisting parachain `1000`,
and its offchain worker successfully submitting `send_init_page`. There were zero post-checkpoint
error, panic, failed-migration, fatal, or essential-task-failure lines; the pre-upgrade checkpoint
also contained none of those future-upgrade signals or severe failures.

The clean candidate build took 13 minutes 53 seconds with two jobs and the repository-root workspace
hint. Spawn reached `network is up and running` in 51 seconds. The strict ordered upgrade completed
in 8 minutes 21 seconds. The post-upgrade verifier took exactly 900 seconds, and the foreground
spawner exited 48 seconds after `make stop` began. The network stopped cleanly with zero related
processes and zero RPC listeners remaining. Results remain local and untracked in
`integration-tests/polkadot-live-fork/artifacts-clean-proof-stable2606-20260830-001`. The retained
artifact uses 26 GiB. After preserving both candidate WASMs and cleaning 6.0 GiB of root Cargo
outputs plus 538.3 MiB from the upgrade client, 230 GiB remained free.
