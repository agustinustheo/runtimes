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

The 2026-08-23 validation built fresh candidates from PR #2 commit `cb2ecf94f`, then reused the
already captured snapshots at the user's request; it did not resynchronize or recapture a chain.
The retained boundaries were Relay `32633720`, Asset Hub `19671181`, People `8761757`, and Bulletin
`1448558`. Their captured runtime versions were `2003002`, `2003002`, `2003002`, and `2002001`.

The exact candidates activated in the run were:

| Candidate | `spec_version` | SHA-256 |
|---|---:|---|
| Asset Hub | `2003004` | `ad6bd8be374b649df4f814b5a80df85da498e88096427431416ab2c5c9a7f9ed` |
| People | `2003004` | `3d8ff55e919f6b9fcaceed6e27b3cb64cd3f803deae1b95b9ebd0f7761f1c8a5` |

Asset Hub upgraded before People. Its PGAS, `NextAssetId`, and Revive migration checks passed before
the People upgrade was submitted. People then exposed the Individuality pallets, sent the pending
initialization XCM, and activated the Asset Hub subscription. The independent verifier confirmed
the exact candidate bytes, consumed authorizations, and unchanged Relay and Bulletin code.

All 15 one-minute samples advanced. Over the full 900 seconds, Relay advanced
`32634013 -> 32634163` (+150), Asset Hub `19672032 -> 19672482` (+450), People
`8762610 -> 8763060` (+450), and Bulletin `1448847 -> 1448997` (+150). The post-checkpoint logs
showed FRAME migration assessments, Asset Hub's `PGAS asset created`, and People's
`lite people collection created`. They also contained recurring parachain
`AuthorityDiscoveryApi_authorities` compatibility noise from the omni-node, present before and
after the upgrades; no panic, failed migration, or essential-task failure appeared.

The network stopped cleanly. RPC ports `61591` through `61595` had no listeners, and no
`polkadot`, parachain node, Zombie Bite, or upgrade-client process remained. Results and snapshots
remain local and untracked in
`integration-tests/polkadot-live-fork/artifacts-rerun-20260822-1408`. After stopped-network working
copies and rejected repair archives were removed, the retained evidence used 3.0 GiB and 251 GiB
remained free.
