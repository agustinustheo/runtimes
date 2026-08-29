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

## Recorded timing from the 2026-08-29 UTC validated run

The validation completed on 2026-08-29 UTC. Candidates were built from PR #2 commit
`72aeee6e54c1f2357b8b2dbab44ce1dd2316d6e0`, which contains signed PR #1 merge
`bb7e123b7c5994fa73330556e53e7d88a306572e` and PR #1233
`1a5410be8244b00fbcec68a5efc54b186220c5c5`. Both artifact-reuse variables were explicitly unset,
and all four production chains were resynchronized into a new artifact directory.

| Phase | Measured duration |
|---|---:|
| Clean candidate build | `13 min 53 s` with `CARGO_BUILD_JOBS=2` |
| Fresh four-chain synchronization to `ready.json` | `2 h 45 min 49 s` |
| Spawn to ready marker | `51 s` |
| Fork verification, pre-upgrade verification, and runtime-log checkpoint | `40 s`, including the `24 s` block-production observation |
| Strict ordered activation attempt | `8 min`, through both activations before the stale metadata assertion |
| Corrected explicit recovery checks | `9 s`, without resubmission |
| Configured post-upgrade verification | Exactly `15 min` |
| Runtime-log extraction and manual audit | About `3 s` |
| Stop request to spawner exit | `21 s` |

The build also set `WASM_BUILD_WORKSPACE_HINT` to the current repository root. The pre-upgrade
block-production check remains 24 seconds. The final verification used the full 900-second default
and sampled all four chains every minute. Asset Hub's public-peer synchronization dominated the
fresh capture time. The local node binaries exactly matched the published Polkadot SDK
`polkadot-stable2606-1` macOS ARM64 artifacts and reported `1.24.1-8ae9775dc43`.

## Recorded boundaries

The manual run recorded these live-fork boundaries:

| Chain | Recorded block |
|---|---:|
| Relay | `32766531` |
| Asset Hub | `20018213` |
| People | `9130240` |
| Bulletin | `1579329` |

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
- The shutdown script ran after the final verification passed.

The strict upgrade invocation started with recovery mode unset and activated Asset Hub before
People. Its post-activation People metadata check then failed because the harness still required the
intentionally removed `Honour` pallet. The assertion was corrected to require the current pallet
set and reject `Honour`; formatting and locked release checks passed. The documented explicit
recovery invocation verified both exact active code blobs, completed the XCM/subscription checks
without resubmission, and exited zero.

The complete default 900-second command then passed and included this final result:

```text
relay: advanced 32766671 -> 32766821
asset-hub: advanced 20018605 -> 20019055
people: advanced 9130635 -> 9131085
bulletin: advanced 1579466 -> 1579616
Only Asset Hub and People upgraded; all four chains continued producing blocks throughout the 900-second post-upgrade observation.
```

This output completes the final 900-second block-production check. Every related process had exited,
all captured RPC, P2P, and metrics ports had no listeners after the spawner exited, and no
artifact-related process remained.

The exact candidate SHA-256 hashes activated in this run were:

- Asset Hub (`2848732` bytes): `e0f27398eccd5f2074943c6526ce633adeee816c50f27ea6032937502f70c80d`
- People (`1787392` bytes): `93badb05d46b54cbbbacc4475dbf7da74058014ac6ba15d6b5511803f451d1e6`

The four non-empty, gzip-valid snapshot artifacts were:

| Chain | Bytes | SHA-256 |
|---|---:|---|
| Relay | `328756950` | `f4fa24062144c6e3a984dd213a690e5acba261c80e79509fdfc912edaacbb6cd` |
| Asset Hub | `2760102854` | `cb2623ed9835487998aa2a36b0b1a2b61a08f415baffc09589b060a5a2823d32` |
| People | `4878485` | `c8dbc7dd83f4cc3a10e27dd6fc8558b19c88f8815f62e2756b300c3fbc3c7a9e` |
| Bulletin | `2594318` | `ef5c97254b34a641824b60e6ce80940f7f18b83c558383808e3b953f1715b2f7` |

The local evidence is retained under
`/Users/theo/Projects/parity/runtimes/integration-tests/polkadot-live-fork/artifacts-clean-proof-stable2606-20260829-001`.
It is intentionally untracked and was not pushed. The validation directory uses 26 GiB, and 243
GiB remained free after clean shutdown. After both exact candidate WASMs were retained under
`candidates` and this run's Cargo targets were cleaned, 250 GiB was free.

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
Preflight began with 276 GiB free; 268 GiB remained after the candidate build and 243 GiB after
clean shutdown. The post-run root and upgrade-client Cargo cleans removed 6.0 GiB and 628.2 MiB,
restoring free space to 250 GiB.

`cargo clean` removes compiled Rust data. It does not remove live-fork snapshots. Cargo cleanup is
not a required step for each test.

## Open-file requirement

Set the soft open-file limit to at least 4,096 before capture:

```sh
ulimit -n 4096
```

The current `bite.sh` also tries to set this limit. The check prevents a late `Too many open files`
failure when Zombie Bite opens the Relay ParityDB.
