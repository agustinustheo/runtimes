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

Both candidates must have runtime version `2004000`. The captured production versions must be
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

- runtime version `2004000` is active
- the exact candidate WASM is active
- PGAS exists
- `Assets.NextAssetId` did not change
- the Revive version 4 migration is historic
- no Individuality subscription exists before the People upgrade

The client checks these People results:

- runtime version `2004000` is active
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

## Recorded timing from the 2026-08-27 validated run

The local timezone was UTC+7. Fresh candidates were built from PR #2 commit
`c21994ae2c17c86c9878e558e824f8f3d512db18`, after merging the latest PR #1233 through PR #1 into
PR #2. Both artifact-reuse variables were explicitly unset and all four production chains were
resynchronized into a new artifact directory.

| Phase | Measured duration |
|---|---:|
| Full-clean candidate build | `13 min 57 s` with `CARGO_BUILD_JOBS=2` |
| Fresh four-chain synchronization to `ready.json` | `43 min 29 s` |
| Final spawn to ready marker | `46 s` |
| Fork verification, pre-upgrade verification, and runtime-log checkpoint | `40 s`, including the `24 s` block-production observation |
| Normal strict Asset Hub then People upgrade | `7 min 8 s` |
| Configured post-upgrade verification | `15 min` plus command overhead |
| Runtime-log extraction | About `1 s` |
| Stop request to spawner exit | `1 min 10 s`, including stopped-state snapshots |

The build also set `WASM_BUILD_WORKSPACE_HINT` to the current repository root. The pre-upgrade
block-production check remains 24 seconds. The final verification used the full 900-second default
and sampled all four chains every minute. Asset Hub was the largest and slowest capture at about 41
minutes. The local node binaries exactly matched the official PreviewNet `v20260826.201435` macOS
ARM64 artifacts and reported `1.24.2-weekly2026w34-eb220fa14e7`.

## Recorded boundaries

The manual run recorded these live-fork boundaries:

| Chain | Recorded block |
|---|---:|
| Relay | `32735774` |
| Asset Hub | `19939360` |
| People | `9050572` |
| Bulletin | `1550125` |

The artifact directory contains the same values in `ready.json`.

## Recorded results

The supplied terminal output proves these results:

- The four live-fork boundary checks passed.
- All four local RPC endpoints became ready.
- The Relay Chain registered parachains `1000`, `1004`, and `1010`.
- Asset Hub and People started at runtime version `2003002`.
- Both candidate authorizations were present.
- All four chains advanced before the upgrades.
- Asset Hub upgraded to `2004000` and its PGAS, `NextAssetId`, and Revive checks passed.
- People upgraded to `2004000` and exposed the current Individuality pallet set.
- The People-to-Asset-Hub XCM completed and Asset Hub activated the subscription.
- Relay remained at runtime version `2003002`.
- Bulletin remained at runtime version `2002001`.
- Asset Hub and People used the exact candidate runtime bytes.
- Both runtime authorizations were consumed.
- All 15 one-minute samples showed all four chains producing blocks after the upgrades.
- The post-checkpoint logs showed XcmpQueue migration from version 6 to 7 on both chains, Asset
  Hub's `PGAS asset created`, and People's `lite people collection created` automatic migration
  hook. The notifier whitelisted parachain `1000` and its offchain worker logged a successful
  `send_init_page` submission.
- The scoped logs contained recurring omni-node `AuthorityDiscoveryApi_authorities` compatibility
  noise before and after the upgrades, but no panic, failed migration, or essential-task failure.
- The shutdown script ran after the final verification passed.

The full upgrade ran on the normal strict path with recovery mode unset and exited zero on its
first invocation. The Bash-3.2-safe optional recovery scalar introduced by the preceding validation
remained in place.

The complete default 900-second command then passed and included this final result:

```text
relay: advanced 32735865 -> 32736015
asset-hub: advanced 19939610 -> 19940060
people: advanced 9050810 -> 9051260
bulletin: advanced 1550214 -> 1550364
Only Asset Hub and People upgraded; all four chains continued producing blocks throughout the 900-second post-upgrade observation.
```

This output completes the final 900-second block-production check. All 36 recorded RPC, P2P, and
metrics ports had no listeners after the spawner exited, and every artifact-related process had
stopped.

The exact candidate SHA-256 hashes activated in this run were:

- Asset Hub: `060a9ebf7805fbcb46e130b7678b243221e1f05f67e9c75897c4d0abfce90ae7`
- People: `8c7f43a8040fafeb2497e382bac4c213d2a5fd7cee26a2260b1c237ace1f3963`

The four non-empty, gzip-valid snapshot artifacts were:

| Chain | Bytes | SHA-256 |
|---|---:|---|
| Relay | `332903965` | `32f3a6ca85674fcf0bb943743552b9431d6c2c67d53d6084f1112e2adac5ada7` |
| Asset Hub | `2757054990` | `a25728299e58e45a20ab4222627ff2c75c9c63c47c5447cb7fe5cb9a2f6d50b4` |
| People | `4861819` | `312fa6bae82385736beaa2b75cc532f3a6e02dae7e671c297b6741ac6050cbef` |
| Bulletin | `2590105` | `67a1ef82b9dcf43d39ef1589c0d4c6da553bd0840dbda96ed46f79aa15b71d33` |

The local evidence is retained under
`/Users/theo/Projects/parity/runtimes/integration-tests/polkadot-live-fork/artifacts-clean-proof-stable2606-20260827-003`.
It is intentionally untracked and was not pushed. The directory uses 27 GiB and 224 GiB remained
free after clean shutdown.

## Warnings and normal waits

The RPC helpers require Node.js 22 or newer so the global WebSocket API is available. Node.js 20
without `--experimental-websocket` fails before live preflight begins.

The `wasm32-unknown-unknown` messages are build warnings. They did not fail this run.

Repeated `waiting for code enactment` messages are normal. Do not interrupt the upgrade client
while the current runtime version changes from `2003002` to `2004000`.

Repeated Asset Hub database messages are also normal while the database becomes quiet. Continue
only if the process still has peers or the downloaded byte count continues to increase.

## Storage requirement

Keep enough free space for the Rust build, captured snapshots, and spawned working copies.

The retained artifact directory uses approximately 27 GiB after the latest run, including 23 GiB
of stopped working databases. Start a cold clean run with at least 250 GiB free because temporary
capture data, build products, and spawned working copies can coexist while the test is active. This
full repository target clean removed 10.2 GiB before the candidates were rebuilt. Preflight
reported 249 GiB free after that build, and 224 GiB remained after clean shutdown.

`cargo clean` removes compiled Rust data. It does not remove live-fork snapshots. Cargo cleanup is
not a required step for each test.

## Open-file requirement

Set the soft open-file limit to at least 4,096 before capture:

```sh
ulimit -n 4096
```

The current `bite.sh` also tries to set this limit. The check prevents a late `Too many open files`
failure when Zombie Bite opens the Relay ParityDB.
