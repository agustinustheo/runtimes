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

The latest validation completed on 2026-08-28 UTC+7 (2026-08-27 UTC) from PR #2 commit
`811338261f9f7fadb82b1273864ecb51e8f94dcb`. That commit contains signed merges of PR #1233 at
`62fd354526b27e6dfc1b64534d77b9c4069e0367` through PR #1 at
`334a81cc0255c3743cd436bdd90d979a73314ec0`. Both local node binaries matched the official
PreviewNet `v20260826.201435` macOS ARM64 assets exactly and reported
`1.24.2-weekly2026w34-eb220fa14e7`.

Both artifact-reuse variables were explicitly unset for a new four-chain production capture. That
capture took 3 hours 12 minutes 54 seconds, mostly waiting for Asset Hub's public peer, and recorded
Relay `32741430`, Asset Hub `19950771`, People `9061825`, and Bulletin `1554250`. Their runtime
versions were `2003002`, `2003002`, `2003002`, and `2002001`. The production capture is retained in
`artifacts-clean-proof-stable2606-20260827-006`.

Three formatting-only base commits landed after capture and changed the reproducible candidate
bytes. Following the retained-capture procedure, the fresh snapshots were restored only to
localhost and materialized into a separate candidate-specific artifact with both reuse controls
still unset. Relay, Asset Hub, and People were materialized at the same captured boundaries with
the final authorizations; Bulletin has no candidate authorization and uses its untouched fresh
production snapshot. No production peer was contacted during this 8-minute-48-second step.

The exact candidates activated in the run were:

| Candidate | `spec_version` | SHA-256 |
|---|---:|---|
| Asset Hub | `2004000` | `7a39bcb6fe809bf81d644263a5ca870a5fa919fdc477f10228f0f235286a7f1e` |
| People | `2004000` | `fdd9c605680597f4e0b5c8e4ccc01d09d8b39321e2df773d9036b4690278292a` |

Asset Hub upgraded before People. Its PGAS, `NextAssetId`, and Revive migration checks passed before
the People upgrade was submitted. People then activated the current Individuality pallet set, sent
the pending initialization XCM, and activated the Asset Hub subscription. The normal strict path
passed on its first invocation with recovery mode unset. The Bash-3.2-safe optional recovery scalar
introduced by the preceding validation remained in place. The independent verifier confirmed the
exact candidate bytes, consumed authorizations, and unchanged Relay and Bulletin code.

The full, unmodified 900-second verifier passed. All 15 one-minute samples advanced. Relay advanced
`32741524 -> 32741674` (+150), Asset Hub `19951030 -> 19951480` (+450), People
`9061916 -> 9062066` (+150), and Bulletin `1554341 -> 1554491` (+150). The post-checkpoint logs
showed XcmpQueue migration from version 6 to 7 on both upgraded chains, Asset Hub's `PGAS asset
created`, People's `lite people collection created`, the notifier whitelisting parachain `1000`,
and its offchain worker submitting `send_init_page`. They also contained recurring parachain
`AuthorityDiscoveryApi_authorities` compatibility noise from the omni-node, present before and
after the upgrades; all 60 such lines matched that one documented pattern. No unexpected error,
panic, failed migration, runtime trap, fatal message, or essential-task failure appeared.

The final clean candidate build took 13 minutes 57 seconds with two jobs and the workspace hint.
Final spawn reached the ready marker in 49 seconds, the normal strict ordered upgrade took 7 minutes
20 seconds, the configured post-upgrade verifier took exactly 900 seconds, and the foreground
spawner exited 47 seconds after `make stop`. The network stopped cleanly: all 42 captured related
PIDs exited, all 36 recorded RPC, P2P, and metrics ports were closed, and `stop.txt` was absent.
Results remain local and untracked in
`integration-tests/polkadot-live-fork/artifacts-clean-proof-stable2606-20260827-007`. The retained
artifact uses 25 GiB, and 216 GiB remained free after shutdown.
