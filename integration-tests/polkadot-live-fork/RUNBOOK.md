# Polkadot Zombie Bite runtime-upgrade runbook

This runbook performs a live-state test of the Individuality changes using four local chains:

- Polkadot Relay;
- Asset Hub Polkadot, parachain `1000`;
- People Polkadot, parachain `1004`; and
- Bulletin Polkadot, parachain `1010`.

The test starts Asset Hub and People on their captured production runtimes. It upgrades Asset Hub
first and People second. Relay and Bulletin remain on their captured runtimes.

## What the test proves

The complete run verifies that:

1. each local chain has a boundary derived from its configured live RPC;
2. Asset Hub and People initially run production `spec_version 2003002`;
3. the exact candidate WASMs built from this checkout are authorized but not initially active;
4. Asset Hub upgrades to `2003003` and completes the PGAS and Revive migrations;
5. People upgrades to `2003003` and sends the pending initialization through a real XCM;
6. Asset Hub receives that XCM and activates the Individuality subscription with `R2e9`;
7. Relay and Bulletin runtime code does not change; and
8. all four chains continue producing blocks.

Bulletin is deliberately not upgraded. Its current live runtime does not contain the transaction
storage receiver needed for the later People-to-Bulletin flow.

## Prerequisites

Run this on macOS ARM64 or Linux x86_64. You need:

- Git, Rust/Cargo, Node.js, `make`, `curl`, `jq`, and `shasum`;
- network access to the four RPC endpoints and Polkadot peers;
- the runtimes checkout containing this harness;
- the Individuality checkout, normally at `../individuality`; and
- a current `polkadot-omni-node` binary at
  `preview-net-v1/bin/polkadot-omni-node` in the primary runtimes checkout.

Set `INDIVIDUALITY_DIR` or `PARACHAIN_NODE_BIN` if those paths differ. Start a cold clean run with
at least 250 GiB free so the Rust builds, capture databases, compressed snapshots, and spawned
working copies can coexist. Asset Hub is the largest state capture.

On systems with a low open-file limit, `make bite` raises its own soft limit to 4,096 before it
opens a captured ParityDB database. If the shell does not permit that increase, the command stops
immediately and tells you to run `ulimit -n 4096`. This check prevents a late `Too many open files`
failure while the Relay Chain snapshot is created.

The expected live and candidate versions are pinned in `versions.env`. If Polkadot has upgraded
since this runbook was written, `make bite` will stop during preflight instead of silently testing a
different starting runtime. Update the expected versions only after reviewing the new live state.

## How the Zombie Bite patch works

Yes, this harness patches Zombie Bite. The patch is tracked in:

```text
patches/zombie-bite-live-fork.patch
```

`make setup` performs these steps automatically:

1. clones `ZOMBIE_BITE_REPOSITORY` into `/tmp/polkadot-zombie-bite-tools/zombie-bite`;
2. checks out the exact `ZOMBIE_BITE_COMMIT` from `versions.env`;
3. applies `patches/zombie-bite-live-fork.patch` with `git apply`;
4. builds the patched Zombie Bite binary in release mode; and
5. records the base commit and patch SHA-256 beside the cached binary.

If the cached checkout contains changes other than the tracked patch, setup fails. The patch does
not modify your global Cargo installation or the source in the runtimes checkout. It only modifies
the pinned checkout under `/tmp`.

The patch adds the multi-parachain capture, ParityDB snapshot handling, candidate authorization,
People subscription fixture, live People-to-Asset-Hub HRMP preservation, shorter fork-local
validation-code delay, artifact-recovery support, and spawn-readiness handling used by this test.

To inspect exactly what is applied:

```sh
make setup
git -C /tmp/polkadot-zombie-bite-tools/zombie-bite status --short
git -C /tmp/polkadot-zombie-bite-tools/zombie-bite diff --check
git -C /tmp/polkadot-zombie-bite-tools/zombie-bite diff --stat
```

## Clean end-to-end run

Use a new artifact directory that has never been used before. This prevents snapshot reuse and is
the strongest reproducibility check. The example name below is only a placeholder; change it for
each clean run.

### Terminal 1: build, capture, and spawn

```sh
cd /absolute/path/to/runtimes/integration-tests/polkadot-live-fork

export ZOMBIE_BITE_ARTIFACTS_DIR="$PWD/artifacts-clean-proof-20260820-01"
unset ZOMBIE_BITE_REUSE_PARA_ARTIFACTS
unset ZOMBIE_BITE_REUSE_RELAY_ARTIFACTS

git rev-parse HEAD
CARGO_BUILD_JOBS=2 make build-wasm
CARGO_BUILD_JOBS=2 make bite
make spawn
```

When using an isolated `CARGO_TARGET_DIR`, export
`WASM_BUILD_WORKSPACE_HINT="$(git rev-parse --show-toplevel)"` before `make build-wasm` so the WASM
builder still resolves the current repository workspace.

Leave `make spawn` running. The default local RPC ports are:

| Chain | RPC |
|---|---|
| Relay | `ws://127.0.0.1:9944` |
| Asset Hub | `ws://127.0.0.1:9910` |
| People | `ws://127.0.0.1:9914` |
| Bulletin | `ws://127.0.0.1:9920` |

The selected ports are also written to `$ZOMBIE_BITE_ARTIFACTS_DIR/ports.json`.

#### Wait for the network-ready message

Do not start the upgrade immediately after invoking `make spawn`. Keep watching Terminal 1 until
Zombie Bite prints a message containing:

```text
network is up and running
```

Before printing that message, Zombie Bite waits for the parachain collator metrics to report an
active node role and observes three finalized Relay Chain blocks. If the message does not appear
within about five minutes, treat startup as failed and inspect the node output and logs instead of
proceeding with the upgrade.

No additional fixed sleep is needed after the ready message. The verification commands also retry
their RPC connections for up to five minutes, but the ready message is the clearest operator
handoff from Terminal 1 to Terminal 2.

### Terminal 2: verify, upgrade, and stop

Use the exact same artifact directory:

```sh
cd /absolute/path/to/runtimes/integration-tests/polkadot-live-fork

export ZOMBIE_BITE_ARTIFACTS_DIR="$PWD/artifacts-clean-proof-20260820-01"

make verify-fork
make verify
make mark-runtime-logs
CARGO_BUILD_JOBS=2 make upgrade
make verify-upgrade
make inspect-runtime-logs
make stop
```

Some waits in this sequence are intentional:

- `make verify-fork` and `make verify` wait up to five minutes for their RPC endpoints if startup
  is still settling.
- `make verify` observes the four chains for 24 seconds to prove that all of them continue
  advancing.
- `make upgrade` polls every six seconds while waiting for code enactment, Asset Hub multi-block
  migrations, and the People Chain XCM upgrade. Leave it running while it prints those waiting
  messages; this can take several minutes.
- `make verify-upgrade` uses a 15-minute post-upgrade observation window and checks every minute
  that all four chains continue to advance.
- `make mark-runtime-logs` records the pre-upgrade Asset Hub and People log positions.
- `make inspect-runtime-logs` prints and preserves the runtime, migration, and Individuality log
  messages written after those positions for manual review.
- `make stop` can take up to about 90 seconds to make the foreground `make spawn` process exit
  because Zombie Bite checks its stop file on that interval.

`make stop` asks the monitor in Terminal 1 to shut down the network. If a verification command
fails, run `make stop` before investigating or starting another network with the same ports.

## Expected success evidence

The run is successful only when all commands exit with status zero. Look for these messages:

```text
All four local chains retain their recorded live-chain fork boundaries.
All four original-runtime forks are reachable and producing blocks.
Asset Hub upgraded to 2003003
People upgraded to 2003003
People-to-Asset-Hub initialization XCM completed; Asset Hub subscription is active
Only Asset Hub and People upgraded; all four chains continued producing blocks throughout the 900-second post-upgrade observation.
```

`make verify-fork` compares each boundary with the corresponding live RPC. The local block hash and
state root are expected to differ because Zombie Bite installs local authorities and narrowly
scoped test storage. The block number, parent hash, extrinsics root, and consensus digest must
match.

`make verify-upgrade` compares active `:code` bytes with the candidate files. A matching
`spec_version` alone is not accepted as proof.

## Reusing a completed capture

Normal verification does not need the reuse environment variables. Keep the completed artifact
directory and run `make spawn` against it again:

```sh
export ZOMBIE_BITE_ARTIFACTS_DIR="$PWD/artifacts-clean-proof-20260820-01"
make spawn
```

Then repeat the verification commands from Terminal 2. A capture that has already been upgraded is
safe to reuse because each `make spawn` creates a new working copy from the captured snapshots; the
captured snapshots themselves are not changed by `make upgrade`.

`ZOMBIE_BITE_REUSE_PARA_ARTIFACTS` and `ZOMBIE_BITE_REUSE_RELAY_ARTIFACTS` are recovery controls for
interrupted capture development. Do not use them for an independent clean proof. They assume that
the matching specs, snapshots, head markers, and block markers are already internally consistent.

## Runtime expectations and timing

The nine-hour development goal was not the duration of one test. It included implementation,
several failed state captures, diagnosis, patch changes, and repeated four-chain runs.

Measured 2026-08-20 timing, which still depends on cache and peer availability:

- fresh two-candidate build with `CARGO_BUILD_JOBS=2`: 14 minutes 13 seconds;
- fresh four-chain capture: 2 hours 25 minutes 41 seconds;
- fresh spawn to the ready message: 44 seconds;
- snapshot-reuse spawn with the explicit runtime log filters: 50 seconds;
- ordered Asset Hub and People upgrade: 8 minutes 21 seconds; and
- final post-upgrade observation: 15 minutes 1 second including command overhead.

A nine-hour clean run is not normal. Treat a capture with no peers or no database growth as stalled.

## Latest validated results

The 2026-08-20 fresh capture recorded Relay `32633720`, Asset Hub `19671181`, People `8761757`,
and Bulletin `1448558`. The captured runtime versions were `2003002`, `2003002`, `2003002`, and
`2002001`. The exact Asset Hub and People `2003003` candidate SHA-256 hashes were
`8725a283cd6b0c42c856076525a14ce159e1273b59d89df4fbd40aa0ec6b4d1d` and
`1f9c932b21146bb7dacad2a712720ff6b18b21fa7fdaede05e3317626268578c`.

The 900-second rerun advanced Relay `32633827 -> 32633977` (+150), Asset Hub
`19671477 -> 19671927` (+450), People `8762055 -> 8762505` (+450), and Bulletin
`1448662 -> 1448812` (+150). Runtime logs showed the FRAME migration assessment on both upgraded
collators, `PGAS asset created` on Asset Hub, and the People notifier's successful
`send_init_page` submission. The scoped log scan found no runtime error, panic, failed migration,
or essential-task failure. After `make stop`, ports `9944`, `9945`, `9910`, `9914`, and `9920`
were closed and every related process had exited.

## Troubleshooting

### WebSocket failure during verification

Confirm `make spawn` is still running and inspect the actual ports:

```sh
jq . "$ZOMBIE_BITE_ARTIFACTS_DIR/ports.json"
```

The verification scripts wait for RPC startup, but they cannot recover a node that exited.

### Capture appears stuck

State capture depends on public peers. Check that the process still has peers and that the artifact
database is growing. If it has remained at zero peers, stop the capture and retry with a new
artifact directory. Do not call an incomplete directory a valid fork.

### `Too many open files`

The harness now raises the `make bite` process limit automatically. If your shell does not allow
the increase, run this in the same terminal before you retry:

```sh
ulimit -n 4096
```

If all three parachain snapshot files, specifications, head files, and block marker files are
complete, you can set `ZOMBIE_BITE_REUSE_PARA_ARTIFACTS=1` for the retry. Do not set
`ZOMBIE_BITE_REUSE_RELAY_ARTIFACTS` unless the Relay snapshot and its marker are also complete.

### `HRMP head mismatch`

This means the relay channel value and Asset Hub's captured `LastHrmpMqcHeads` disagree. A clean run
fetches the live People-to-Asset-Hub channel value before capture. Do not synthesize an empty channel
or reuse a relay database produced by an older patch.

### Live `spec_version` does not match

The production chain moved beyond the values pinned in `versions.env`. Review the live upgrade and
the candidate version before changing the pins. The candidate must have a higher version than the
captured runtime.

### Missing Individuality checkout

Point the build script at it explicitly:

```sh
export INDIVIDUALITY_DIR=/absolute/path/to/individuality
make build-wasm
```

### Missing parachain node

Set the existing binary path explicitly:

```sh
export PARACHAIN_NODE_BIN=/absolute/path/to/polkadot-omni-node
make setup
```

## Retain evidence

For a reviewable run, retain:

- the tested Git commit from `git rev-parse HEAD`;
- command output from all lifecycle steps;
- `ready.json` and `upgrade-baseline.json`;
- SHA-256 hashes of the Asset Hub and People candidate WASMs; and
- the relevant node logs under the artifact directory.

The artifacts are intentionally ignored by Git because they are large and machine-specific.
