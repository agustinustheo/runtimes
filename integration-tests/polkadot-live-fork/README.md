# Polkadot live-state runtime upgrades with Zombie Bite

This harness captures the live state of the Polkadot Relay chain, Asset Hub (1000), People (1004), and Bulletin (1010). The harness starts all four chains with their captured production runtimes. The harness then applies the runtime candidates that you build from this checkout.

This copy of the harness tests a later upgrade. The first Individuality deployment (PR #1233) is already live at `spec_version` `2005000` on Asset Hub and People. The harness applies the candidates in this order:

1. Asset Hub.
2. People.

The order is the same as for the first deployment, but the order is no longer a requirement. The harness keeps the order so that each run is the same.

The candidate branch must use a `spec_version` that is higher than the live version. FRAME rejects a runtime upgrade that does not increase `spec_version`. The test branch thus increases Asset Hub and People to `2005001`. Do not copy that change into the PR under test.

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
- the People-to-Asset-Hub notifier fixture is pending, or the captured runtime already completed the initialization; and
- the Relay chain, Asset Hub, People, and Bulletin all advance.

The notifier fixture represents the subscription of Asset Hub (`1000`) to the People collection. The captured People runtime already contains `MembersNotifier`. Thus the offchain worker of the captured runtime can send the initialization XCM before the upgrade. The harness accepts this result. After the upgrades, the harness makes sure that the subscription is still active on both chains. The fixture does not give root to an account, and it does not bypass XCM execution.

`make upgrade` submits unsigned `System.apply_authorized_upgrade` extrinsics, first on Asset Hub and then on People. FRAME checks the pre-authorized code hash and version before it routes the code through the parachain runtime-upgrade path. The upgrade client then checks that:

- the exact candidate code and `spec_version` became active;
- the PGAS asset `49_999_999` still exists on Asset Hub, and `Assets.NextAssetId` did not change;
- no multi-block migration is still in progress on Asset Hub;
- the metadata contains each pallet in `ASSET_HUB_EXPECTED_NEW_PALLETS` and `PEOPLE_EXPECTED_NEW_PALLETS` (`versions.env`);
- the People metadata contains the Individuality pallet set; and
- after the People upgrade, the People-to-Asset-Hub subscription is active on both chains.

`make verify-upgrade` makes an independent check that proves three facts. The upgrades consumed both authorizations. The Relay chain code and the Bulletin code did not change. All four chains continue to produce blocks throughout a 15-minute observation. `make mark-runtime-logs` and `make inspect-runtime-logs` isolate the Asset Hub and People runtime, migration, and Individuality messages written during and after the upgrades for manual review.

This harness gives evidence of live-state upgrades and of targeted cross-chain operation. The harness does not replace the execution of production governance, compatibility tests with external clients, or the later Bulletin receiver upgrade.

## Validation status

This harness has not run against this target yet. The recorded results in [TEST_PROCEDURE.md](TEST_PROCEDURE.md) and [COMMANDS_AND_EXPECTED_OUTPUT.md](COMMANDS_AND_EXPECTED_OUTPUT.md) come from the PR #1233 run on 2026-09-01. That run upgraded from `2003002` to `2004000`. Use those files for the procedure and for the approximate durations, not for the expected values.

The local node binaries for that run reported `1.24.1-8ae9775dc43` (`polkadot-stable2606-1`). If the candidate needs a newer node, set `PARACHAIN_NODE_BIN`.
