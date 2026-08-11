# Polkadot live-state runtime upgrades with Zombie Bite

This harness captures live Polkadot Relay, Asset Hub (1000), People (1004), and Bulletin (1010) state, starts all four chains with their captured production runtimes, and then applies the runtime candidates built from this checkout.

PR #1233 requires two upgrades in this order:

1. Asset Hub, so the PGAS asset and the Asset Hub side of the Individuality protocol exist.
2. People, so the People pallets and notifier can send to the already-upgraded Asset Hub.

Relay and Bulletin are deliberately not upgraded. Bulletin's current live runtime does not contain `pallet-transaction-storage`, so People-to-Bulletin long-term storage cannot succeed until a separate future Bulletin runtime upgrade supplies that receiver. The harness does not claim that unavailable flow works.

Zombie Bite and Doppelganger are pinned in `versions.env`. The pinned patch adds the multi-parachain live-fork support needed here, lets ParityDB writes settle after the target block is imported, stops the capture node, reopens the database to replay pending logs and verify the pruning metadata, and only then snapshots it. It also imports candidate-specific `System.AuthorizedUpgrade` values, fetches and retains the exact live People-to-Asset-Hub HRMP channel and MQC head required by the targeted XCM scenario, and tolerates the initial metrics window during spawn. Generated state, chain specs, and logs are ignored by Git.

The default database is pruned ParityDB. This avoids the oversized RocksDB pruning-journal failure seen on macOS while still retaining the captured current state needed for the upgrades.

## Run the complete lifecycle

Build the two candidate WASMs first. The harness expects both candidates to use a `spec_version` higher than the captured live versions.

```sh
cd integration-tests/polkadot-live-fork
make build-wasm
make bite
make spawn
```

Keep `make spawn` running. In another shell:

```sh
make verify-fork
make verify
make upgrade
make verify-upgrade
make stop
```

The default runtime artifacts come from the primary runtimes checkout's `target/release/wbuild`. Override `RUNTIMES_TARGET_DIR`, `ASSET_HUB_WASM`, or `PEOPLE_WASM` when needed. The default RPC ports are Relay `9944`, Asset Hub `9910`, People `9914`, and Bulletin `9920`; the actual ports are recorded in `artifacts-upgrade-paritydb/ports.json`.

## What each phase proves

`make verify-fork` independently checks live provenance at the captured boundary. The local header must match the configured live RPC's block number, parent hash, extrinsics root, and consensus digest. The boundary block hash and state root may differ because Zombie Bite installs local authority and narrowly scoped test storage.

`make verify` runs before upgrades. It proves that:

- all three parachains are registered in the relay state;
- Asset Hub and People still run the captured live runtime code and live `spec_version`, not the candidates;
- both chains contain an authorization for their exact candidate code hash;
- the local relay retains the live People-to-Asset-Hub HRMP channel and MQC head used by the scenario;
- the pending People-to-Asset-Hub notifier fixture is present; and
- Relay, Asset Hub, People, and Bulletin all advance.

The notifier fixture represents the governance subscription that production rollout must create. It is written under storage prefixes that do not exist in the captured People runtime; it becomes readable only after the People candidate is enacted. It does not grant an account root or bypass XCM execution.

`make upgrade` submits unsigned `System.apply_authorized_upgrade` extrinsics, first on Asset Hub and then on People. FRAME checks the pre-authorized code hash and version before routing the code through the parachain runtime-upgrade path. The upgrade client then checks:

- the exact candidate code and `spec_version` became active;
- Asset Hub created PGAS asset `2_000_000_000` without changing `Assets.NextAssetId`;
- the Revive v4 multi-block migration completed and is recorded as historic; and
- after the People upgrade, its authorized notifier maintenance call sends a real XCM that activates `MembersSubscriber` on Asset Hub.

`make verify-upgrade` independently proves that both authorizations were consumed, Relay and Bulletin code remained unchanged, and all four chains continue producing blocks.

This is live-state upgrade and targeted cross-chain evidence. It does not replace production governance execution, external-client compatibility testing, or the later Bulletin receiver upgrade.
