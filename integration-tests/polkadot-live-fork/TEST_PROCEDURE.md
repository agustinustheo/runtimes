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

## Recorded timing from the 2026-08-30 UTC validated run

The validation completed on 2026-08-30 UTC. Candidates were built from PR #2 commit
`d8a48ef6af14465a734cbd099ba9bc8e6e0d727c`, which contains signed PR #1 merge
`5b1652923abe49a21dba21ad352f9580dee56e2e` and PR #1233
`a72ba8b15a046f28d10b1052860671da4ec13d37`. Both artifact-reuse variables were explicitly unset,
and all four production chains were resynchronized into a new artifact directory.

| Phase | Measured duration |
|---|---:|
| Clean candidate build | `13 min 53 s` with `CARGO_BUILD_JOBS=2` |
| Fresh four-chain synchronization to `ready.json` | `3 h 54 min 39 s` |
| Spawn to ready marker | `51 s` |
| Fork verification, pre-upgrade verification, and runtime-log checkpoint | `39 s`, including the `24 s` block-production observation |
| Strict ordered Asset Hub then People activation | `8 min 21 s`, with recovery mode unset |
| Configured post-upgrade verification | Exactly `15 min` |
| Runtime-log extraction and manual audit | About `1 s` |
| Stop request to spawner exit | `48 s` |

The build also set `WASM_BUILD_WORKSPACE_HINT` to the current repository root. The pre-upgrade
block-production check remains 24 seconds. The final verification used the full 900-second default
and sampled all four chains every minute. Asset Hub's public-peer synchronization dominated the
fresh capture time. The local node binaries exactly matched the published Polkadot SDK
`polkadot-stable2606-1` macOS ARM64 artifacts and reported `1.24.1-8ae9775dc43`.

## Recorded boundaries

The manual run recorded these live-fork boundaries:

| Chain | Recorded block |
|---|---:|
| Relay | `32776366` |
| Asset Hub | `20043704` |
| People | `9155490` |
| Bulletin | `1588607` |

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
- The scoped post-checkpoint logs contained zero error, panic, failed-migration, runtime-trap,
  fatal, or essential-task-failure lines.
- The pre-upgrade checkpoint contained none of the future-upgrade signals and no severe failures.
- The shutdown script ran after the final verification passed.

The strict upgrade invocation started with recovery mode unset, activated Asset Hub before People,
verified both exact active code blobs, completed the XCM/subscription checks, and exited zero. No
recovery invocation was needed.

The complete default 900-second command then passed and included this final result:

```text
relay: advanced 32776473 -> 32776623
asset-hub: advanced 20043991 -> 20044441
people: advanced 9155788 -> 9156238
bulletin: advanced 1588711 -> 1588861
Only Asset Hub and People upgraded; all four chains continued producing blocks throughout the 900-second post-upgrade observation.
```

This output completes the final 900-second block-production check. Every related process had exited,
all captured RPC, P2P, and metrics ports had no listeners after the spawner exited, and no
artifact-related process remained.

The exact candidate SHA-256 hashes activated in this run were:

- Asset Hub (`2848732` bytes): `e0f27398eccd5f2074943c6526ce633adeee816c50f27ea6032937502f70c80d`
- People (`1783780` bytes): `bc147e251052eb6ba566dda20297a640aa1f451dfcf94e2546d86179026ff13a`

The four non-empty, gzip-valid snapshot artifacts were:

| Chain | Bytes | SHA-256 |
|---|---:|---|
| Relay | `330077462` | `733964bc388042a6a6ede7455cc5688454ea50ef1b73729168b4c145c389d03d` |
| Asset Hub | `2762783876` | `e84b0931ba119f52c5a6f1e8a911e7954c51fb5339b35ff00f11006e3421c8e3` |
| People | `4868464` | `09cb4dc8a1abf1d630d1bc6baa1c70ecb49c53ab964c92ccdf2f7101b5358e76` |
| Bulletin | `2587729` | `b94841283f9f52a3cc46789226d3bf872e7ea7389cebfc468504d67d014c0e20` |

The local evidence is retained under
`/Users/theo/Projects/parity/runtimes/integration-tests/polkadot-live-fork/artifacts-clean-proof-stable2606-20260830-001`.
It is intentionally untracked and was not pushed. The validation directory uses 26 GiB. After both
exact candidate WASMs were retained under `candidates` and this run's Cargo targets were cleaned,
230 GiB was free.

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

The retained final validation directory uses approximately 26 GiB after the latest run. Start a
cold clean run with at least 250 GiB free because temporary
capture data, build products, and spawned working copies can coexist while the test is active.
Preflight began with 253 GiB free; 247 GiB remained after the candidate build and 224 GiB after
clean shutdown. The post-run root and upgrade-client Cargo cleans removed 6.0 GiB and 538.3 MiB,
restoring free space to 230 GiB.

`cargo clean` removes compiled Rust data. It does not remove live-fork snapshots. Cargo cleanup is
not a required step for each test.

## Open-file requirement

Set the soft open-file limit to at least 4,096 before capture:

```sh
ulimit -n 4096
```

The current `bite.sh` also tries to set this limit. The check prevents a late `Too many open files`
failure when Zombie Bite opens the Relay ParityDB.
