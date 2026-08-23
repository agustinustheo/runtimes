# Polkadot live-fork runtime-upgrade test procedure

## Purpose

This procedure tests the Individuality runtime changes against captured Polkadot production state.

The test uses four local chains:

- Polkadot Relay Chain
- Asset Hub Polkadot, parachain `1000`
- People Polkadot, parachain `1004`
- Bulletin Polkadot, parachain `1010`

Zombie Bite captures state from the four live chains. It then starts local chains from the captured
state.

Asset Hub and People start with their captured production runtimes. The test upgrades Asset Hub
first. It upgrades People second.

Relay and Bulletin do not receive a runtime upgrade.

## Why two runtime upgrades are necessary

Asset Hub must upgrade before People.

The Asset Hub upgrade installs the PGAS asset and the Asset Hub side of the Individuality
protocol. The People upgrade then sends an XCM initialization message to the upgraded Asset Hub.

XCM is the cross-chain message format.

The test does not upgrade Bulletin. The captured Bulletin runtime does not have the transaction
storage receiver for the future People-to-Bulletin flow.

## What a live fork means in this test

The local chains use state from recorded production blocks.

Zombie Bite changes local authority data and adds limited test storage. Therefore, a local block
hash and state root can differ from the live values.

`make verify-fork` compares the fields that must remain canonical:

- block number
- parent hash
- extrinsics root
- consensus digest

This comparison proves that the local boundary came from the configured live chain.

## Test phases

### 1. Build the candidate runtimes

`make build-wasm` builds the Asset Hub and People runtime WASM files from the current checkout.

WASM is the WebAssembly runtime file that the chain executes.

Both candidates must have runtime version `2003003`. The captured production versions must be
`2003002`.

### 2. Capture fresh live state

`make bite` checks the live chain names, genesis hashes, and runtime versions. It then captures the
three parachains and the Relay Chain.

The command writes chain specifications, snapshots, and `ready.json` to the selected artifact
directory.

Use a new artifact directory for a clean proof. Do not set the snapshot reuse variables during a
clean proof.

### 3. Start the local network

`make spawn` restores the four captured chains and starts their local nodes.

Keep this command active in Terminal 1. Wait for this message:

```text
network is up and running
```

The message appears after Zombie Bite observes three finalized Relay Chain blocks.

### 4. Verify the fork boundaries

Run `make verify-fork` in Terminal 2.

This command compares each recorded local boundary with the related live RPC endpoint.

RPC means remote procedure call. An RPC endpoint lets the test read chain data.

### 5. Verify the state before the upgrades

Run `make verify`.

This command proves these conditions:

- Parachains `1000`, `1004`, and `1010` are registered.
- Asset Hub and People still use runtime version `2003002`.
- The exact Asset Hub and People candidate hashes are authorized.
- The People-to-Asset-Hub channel state is present.
- The pending People initialization fixture is present.
- All four chains produce blocks.

The command observes block production for 24 seconds.

Run `make mark-runtime-logs` after this check. It records the current Asset Hub and People
collator log positions so the later inspection only includes output written during and after the
upgrades.

### 6. Apply the runtime upgrades

Run `make upgrade`.

The upgrade client submits an authorized Asset Hub upgrade. It waits for code enactment and the
multi-block migrations.

The client then submits the People upgrade. It waits for the People-to-Asset-Hub XCM result.

The client checks these Asset Hub results:

- runtime version `2003003` is active
- the exact candidate WASM is active
- PGAS exists
- `Assets.NextAssetId` did not change
- the Revive version 4 migration is historic
- no Individuality subscription exists before the People upgrade

The client checks these People results:

- runtime version `2003003` is active
- the Individuality pallets are present
- the pending initialization is consumed
- Asset Hub receives the XCM
- the Asset Hub subscription becomes active

### 7. Verify the final state

Run `make verify-upgrade`.

This command checks the exact active runtime bytes. It does not accept only a matching runtime
version.

It also checks these conditions:

- both runtime authorizations were consumed
- Relay runtime code did not change
- Bulletin runtime code did not change
- all four chains continue to produce blocks

The final block-production check observes all four chains for 15 minutes and requires every chain
to advance during each one-minute interval.

Run `make inspect-runtime-logs` after the observation. Review the post-checkpoint Asset Hub and
People excerpts for the runtime migration assessment and automatic Individuality hooks.

### 8. Stop the network

Run `make stop` after all checks pass.

Terminal 1 can take up to approximately 90 seconds to exit while Zombie Bite observes its stop
file and tears down every node.

## Recorded timing from the 2026-08-23 validated run

The local timezone was UTC+7. The user requested reuse of the retained capture, so no production
chain was resynchronized. Fresh candidates were built before the local network was restored.

| Phase | Measured duration |
|---|---:|
| Fresh candidate outputs completed | Asset Hub `10:28`, People `10:38` UTC+7; start timestamp not retained |
| Production state synchronization | Skipped as requested |
| Snapshot restoration to ready marker | `42 s` |
| Successful fork-boundary verification | `1 min 20 s` including public-RPC latency |
| Pre-upgrade verification | `25 s` |
| Runtime-log checkpoint | `<1 s` |
| Ordered Asset Hub then People upgrade | `7 min 26 s` |
| Configured post-upgrade verification | `15 min` plus sub-second overhead |
| Runtime-log extraction | `1 s` |
| Stop request to spawner exit | `22 s` |

The pre-upgrade block-production check remains 24 seconds. The final verification used the full
900-second default and sampled all four chains every minute. Synchronization time depends on public
peer availability; Asset Hub was the largest and slowest capture.

## Recorded boundaries

The manual run recorded these live-fork boundaries:

| Chain | Recorded block |
|---|---:|
| Relay | `32633720` |
| Asset Hub | `19671181` |
| People | `8761757` |
| Bulletin | `1448558` |

The artifact directory contains the same values in `ready.json`.

## Recorded results

The supplied terminal output proves these results:

- The four live-fork boundary checks passed.
- All four local RPC endpoints became ready.
- The Relay Chain registered parachains `1000`, `1004`, and `1010`.
- Asset Hub and People started at runtime version `2003002`.
- Both candidate authorizations were present.
- All four chains advanced before the upgrades.
- Asset Hub upgraded to `2003004`.
- The Asset Hub PGAS and Revive checks passed.
- People upgraded to `2003004`.
- The Individuality pallets appeared in People metadata.
- The People-to-Asset-Hub XCM completed.
- Asset Hub activated the Individuality subscription.
- Relay remained at runtime version `2003002`.
- Bulletin remained at runtime version `2002001`.
- Asset Hub and People used the exact candidate runtime bytes.
- Both runtime authorizations were consumed.
- All 15 one-minute samples showed all four chains producing blocks after the upgrades.
- The post-checkpoint logs showed both migration assessments, Asset Hub's `PGAS asset created`, and
  People's `lite people collection created` automatic migration hook.
- The scoped logs contained recurring omni-node `AuthorityDiscoveryApi_authorities` compatibility
  noise before and after the upgrades, but no panic, failed migration, or essential-task failure.
- The shutdown script ran after the final verification passed.

The complete Terminal 2 output included this final result:

```text
relay: advanced 32634013 -> 32634163
asset-hub: advanced 19672032 -> 19672482
people: advanced 8762610 -> 8763060
bulletin: advanced 1448847 -> 1448997
Only Asset Hub and People upgraded; all four chains continued producing blocks throughout the 900-second post-upgrade observation.
./scripts/stop.sh
```

This output completes the final 900-second block-production check. RPC ports `61591` through
`61595` had no listeners after the monitor exited, and every related process had stopped.

The exact candidate SHA-256 hashes activated in this run were:

- Asset Hub: `ad6bd8be374b649df4f814b5a80df85da498e88096427431416ab2c5c9a7f9ed`
- People: `3d8ff55e919f6b9fcaceed6e27b3cb64cd3f803deae1b95b9ebd0f7761f1c8a5`

The four non-empty snapshot artifacts were:

| Chain | Bytes | SHA-256 |
|---|---:|---|
| Relay | `222648491` | `68f12831e82e79a317edabf8a1b3f431e6b74ec8048b5c191b21d132d98bf5c7` |
| Asset Hub | `2693327297` | `e30041c591da2a7d7e904fde542faaea4ad9a8fa17ddba8257ba09e83f5295d1` |
| People | `4857392` | `f5cf2b83922a670e0318ff13d6273fcac28cf3093e952eeba225d53190ec40ac` |
| Bulletin | `2898112` | `e84cc7285aeabe70c744fc5e5d3ed5d09e4c00f0ef5c372c431cdc7ca10051e3` |

The local evidence is retained under
`/Users/theo/Projects/parity/runtimes/integration-tests/polkadot-live-fork/artifacts-rerun-20260822-1408`.
It is intentionally untracked and was not pushed.

## Warnings and normal waits

The `wasm32-unknown-unknown` messages are build warnings. They did not fail this run.

Repeated `waiting for code enactment` messages are normal. Do not interrupt the upgrade client
while the current runtime version changes from `2003002` to `2003003`.

Repeated Asset Hub database messages are also normal while the database becomes quiet. Continue
only if the process still has peers or the downloaded byte count continues to increase.

## Storage requirement

Keep enough free space for the Rust build, captured snapshots, and spawned working copies.

The retained artifact directory used approximately 3.0 GiB after the run. Start a cold clean
run with at least 250 GiB free because temporary capture data, build products, and spawned working
copies can coexist while the test is active. The final filesystem check reported 251 GiB free.

`cargo clean` removes compiled Rust data. It does not remove live-fork snapshots. Cargo cleanup is
not a required step for each test.

## Open-file requirement

Set the soft open-file limit to at least 4,096 before capture:

```sh
ulimit -n 4096
```

The current `bite.sh` also tries to set this limit. The check prevents a late `Too many open files`
failure when Zombie Bite opens the Relay ParityDB.
