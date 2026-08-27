# Polkadot live-fork test commands and expected output

This document gives the exact command order. It also gives shortened output samples.

The samples omit repeated progress lines and long node commands. Text in angle brackets is a
placeholder.

Do not run the Terminal 2 commands until Terminal 1 reports that the network is ready.

## 1. Open Terminal 1

Go to the test directory:

```sh
cd /absolute/path/to/runtimes/integration-tests/polkadot-live-fork
```

Set the open-file limit:

```sh
ulimit -n 4096
ulimit -n
```

Expected result:

```text
4096
```

The value can be greater than 4,096. Do not continue if it is less than 4,096.

## 2. Select a new artifact directory

Use a name that does not exist. Change the run identifier for each clean run:

```sh
export RUN_ID=manual-20260820-01
export ZOMBIE_BITE_ARTIFACTS_DIR="$PWD/artifacts-clean-proof-$RUN_ID"

unset ZOMBIE_BITE_REUSE_PARA_ARTIFACTS
unset ZOMBIE_BITE_REUSE_RELAY_ARTIFACTS

test ! -e "$ZOMBIE_BITE_ARTIFACTS_DIR"
```

Expected result:

```text
<no output and exit status 0>
```

If the last command returns a nonzero status, choose a different `RUN_ID`.

## 3. Build the runtime candidates

Run:

```sh
CARGO_BUILD_JOBS=2 make build-wasm
```

If you deliberately use an isolated Cargo target, also point the WASM builder back to this
repository root:

```sh
CARGO_TARGET_DIR=/absolute/path/to/isolated-target \
  WASM_BUILD_WORKSPACE_HINT="$(git rev-parse --show-toplevel)" \
  CARGO_BUILD_JOBS=2 make build-wasm
```

Expected result:

```text
./scripts/build-wasm.sh
warning: asset-hub-polkadot-runtime@1.0.0: You are building WASM runtime using `wasm32-unknown-unknown` target...
warning: people-polkadot-runtime@1.0.0: You are building WASM runtime using `wasm32-unknown-unknown` target...
    Finished `release` profile [optimized] target(s) in <time>
Built Asset Hub and People candidate runtimes at spec_version 2004000
```

The target warnings are not failures. The final `Built` line and exit status zero are required.

## 4. Capture fresh live state

Run:

```sh
CARGO_BUILD_JOBS=2 make bite
```

Expected preflight sample:

```text
./scripts/bite.sh
Zombie Bite and Doppelganger are ready in /tmp/polkadot-zombie-bite-tools
relay: Polkadot, block <live-block>, spec 2003002, genesis 0x91b171bb...
asset-hub: Polkadot Asset Hub, block <live-block>, spec 2003002, genesis 0x68d56f15...
people: Polkadot People, block <live-block>, spec 2003002, genesis 0x67fa177a...
bulletin: Polkadot Bulletin, block <live-block>, spec 2002001, genesis 0x2761c952...
```

Expected synchronization sample:

```text
Starting sync for parachain: asset-hub-polkadot
Starting sync for parachain: people-polkadot
Starting sync for parachain: 1010-polkadot
Syncing...
Synced (chain: people-polkadot), stopping node.
Synced (chain: 1010-polkadot), stopping node.
ParityDB is quiescent at <people-database-path>
ParityDB is quiescent at <bulletin-database-path>
Syncing...
Synced (chain: asset-hub-polkadot), stopping node.
ParityDB has a recoverable background reindex at <asset-hub-database-path>; waiting for writes to settle
...
ParityDB is quiescent at <asset-hub-database-path>
generated with path <artifact-directory>/bite/asset-hub-polkadot-snap.tgz
generated with path <artifact-directory>/bite/people-polkadot-snap.tgz
generated with path <artifact-directory>/bite/1010-polkadot-snap.tgz
Syncing...
Synced (chain: polkadot)
generated with path <artifact-directory>/bite/polkadot-snap.tgz
```

The command can be quiet when a state download is slow. Check the related log if you need more
detail.

Do not run `make spawn` until `make bite` returns to the shell with exit status zero.

The 2026-08-27 fresh capture took 1 hour 7 minutes 54 seconds. Capture time depends on public peer
availability and can vary substantially.

## 5. Confirm the capture files

Run:

```sh
jq . "$ZOMBIE_BITE_ARTIFACTS_DIR/ready.json"
ls -lh "$ZOMBIE_BITE_ARTIFACTS_DIR/bite/"*-snap.tgz
```

Expected `ready.json` shape:

```json
{
  "para_1000_start_block": 19931859,
  "para_1004_start_block": 9043172,
  "para_1010_start_block": 1547416,
  "rc_start_block": 32733261
}
```

The block numbers change in a new capture.

Expected snapshot names:

```text
1010-polkadot-snap.tgz
asset-hub-polkadot-snap.tgz
people-polkadot-snap.tgz
polkadot-snap.tgz
```

All four files must exist and must have nonzero sizes.

## 6. Start the local network in Terminal 1

Run in Terminal 1:

```sh
make spawn
```

Keep this command active.

Expected startup sample:

```text
./scripts/spawn.sh
spawning from <artifact-directory>/bite/config.toml
...
Collator-1000, should be running now
Collator-1004, should be running now
Collator-1010, should be running now
Block #<relay-block-1>
Block #<relay-block-2>
Block #<relay-block-3>
network is up and running...
```

The 2026-08-27 fresh run took 49 seconds from `make spawn` to the ready message with the explicit
runtime log filters enabled.

Leave Terminal 1 open. Continue in Terminal 2.

## 7. Open Terminal 2

Go to the same test directory:

```sh
cd /absolute/path/to/runtimes/integration-tests/polkadot-live-fork
```

Set the exact same artifact directory. Use the same run identifier as Terminal 1:

```sh
export RUN_ID=manual-20260820-01
export ZOMBIE_BITE_ARTIFACTS_DIR="$PWD/artifacts-clean-proof-$RUN_ID"
```

Run each command separately. Continue only if the command exits with status zero.

## 8. Verify the live-fork boundaries

Run in Terminal 2:

```sh
make verify-fork
```

Expected sample:

```text
Checking recorded bite boundaries against the configured live RPCs...
relay: live fork boundary confirmed at block <block>
  live canonical hash: 0x<hash>
  local rewritten hash: 0x<hash>
  canonical parent:     0x<hash>
  state root rewritten as expected for runtime/authority overrides
asset-hub: live fork boundary confirmed at block <block>
...
people: live fork boundary confirmed at block <block>
...
bulletin: live fork boundary confirmed at block <block>
...
All four local chains retain their recorded live-chain fork boundaries.
```

The local hash can differ from the live hash. The local authority and test-state changes cause that
difference.

## 9. Verify the state before the upgrades

Run in Terminal 2:

```sh
make verify
```

Expected sample:

```text
waiting up to 300s for all four local RPCs...
relay: RPC ready at ws://127.0.0.1:9944
asset-hub: RPC ready at ws://127.0.0.1:9910
people: RPC ready at ws://127.0.0.1:9914
bulletin: RPC ready at ws://127.0.0.1:9920
relay registered parachains: 1000, 1004, 1010
relay retained live People-to-Asset-Hub HRMP head 0x<hash>
asset-hub: original live runtime 2003002; candidate authorization present
people: original live runtime 2003002; candidate authorization present
people: pending Asset Hub notifier initialization fixture present
recorded pre-upgrade runtime baseline
relay: Polkadot, initial local block <block>
asset-hub: Polkadot Asset Hub, initial local block <block>
people: Polkadot People, initial local block <block>
bulletin: Polkadot Bulletin, initial local block <block>
relay: advanced <before> -> <after>
asset-hub: advanced <before> -> <after>
people: advanced <before> -> <after>
bulletin: advanced <before> -> <after>
All four original-runtime forks are reachable and producing blocks.
```

The command includes a 24-second block-production check.

Before applying either upgrade, record the current end of the Asset Hub and People collator logs:

```sh
make mark-runtime-logs
```

Expected result:

```text
Collator-1000: marked <artifact-directory>/spawn/Collator-1000/Collator-1000.log
Collator-1004: marked <artifact-directory>/spawn/Collator-1004/Collator-1004.log
```

## 10. Upgrade Asset Hub and People

Run in Terminal 2:

```sh
CARGO_BUILD_JOBS=2 make upgrade
```

Expected Asset Hub sample:

```text
./scripts/upgrade.sh
Finished `release` profile [optimized] target(s) in <time>
submitting unsigned System.apply_authorized_upgrade: spec 2003002 -> 2004000
upgrade extrinsic finalized successfully
waiting for code enactment (current spec 2003002)
... repeated while the upgrade is pending ...
waiting for code enactment (current spec 2004000)
Asset Hub code is active at spec 2004000; waiting for multi-block migrations
... repeated while migrations run ...
Asset Hub upgraded to 2004000; PGAS exists, NextAssetId is preserved, Revive v4 is historic, and no Individuality subscription exists before People upgrades
```

Expected People sample:

```text
submitting unsigned System.apply_authorized_upgrade: spec 2003002 -> 2004000
upgrade extrinsic finalized successfully
waiting for code enactment (current spec 2003002)
... repeated while the upgrade is pending ...
waiting for code enactment (current spec 2004000)
People upgraded to 2004000; the current Individuality pallet set is present in live metadata
waiting for Individuality XCM (subscriber=true, pending=true, subscription=false, exponent=false)
waiting for Individuality XCM (subscriber=true, pending=false, subscription=false, exponent=false)
... repeated while the XCM completes ...
People-to-Asset-Hub initialization XCM completed; Asset Hub subscription is active
Asset Hub and People runtime upgrades completed in the required order.
```

Do not interrupt repeated waiting messages. The client checks the state every six seconds. Its
default timeout is 1,200 seconds for each upgrade invocation.

Normal runs must leave `ZOMBIE_BITE_ALLOW_ALREADY_ACTIVE_CANDIDATES` unset. If the exact runtime
upgrades have already activated but a later harness-only assertion fails, fix and validate that
assertion first. Only then may the same run resume its post-activation checks explicitly:

```sh
ZOMBIE_BITE_ALLOW_ALREADY_ACTIVE_CANDIDATES=1 CARGO_BUILD_JOBS=2 make upgrade
```

This recovery control accepts only the exact configured candidate code at the exact expected
`spec_version`. It does not resubmit either upgrade. Without the variable, the client rejects an
already-active candidate.

## 11. Verify the final state

Run in Terminal 2:

```sh
make verify-upgrade
```

Expected complete result:

```text
relay: runtime unchanged at 2003002
asset-hub: candidate runtime 2004000 active
people: candidate runtime 2004000 active
bulletin: runtime unchanged at 2002001
Observing all four chains for 900 seconds after the upgrades...
post-upgrade +60s: relay <before> -> <after>, asset-hub <before> -> <after>, people <before> -> <after>, bulletin <before> -> <after>
... repeated every 60 seconds through 900 seconds ...
relay: advanced <before> -> <after>
asset-hub: advanced <before> -> <after>
people: advanced <before> -> <after>
bulletin: advanced <before> -> <after>
Only Asset Hub and People upgraded; all four chains continued producing blocks throughout the 900-second post-upgrade observation.
```

Do not stop after the four runtime lines. By default, the command observes all four chains for 900
seconds, checking every 60 seconds that every chain advanced. The final summary line is required.
For a local script smoke test only, the duration can be overridden with
`POST_UPGRADE_OBSERVATION_SECONDS`; a release-validation run must use the 900-second default.

Inspect the Asset Hub and People collator output written since the pre-upgrade checkpoint:

```sh
make inspect-runtime-logs
```

The output must contain the runtime-upgrade and migration assessment on both collators. In the
latest 2026-08-27 run it included XcmpQueue migration from version 6 to 7 on both chains, `PGAS
asset created` on Asset Hub, `lite people collection created` on People, and a successful notifier
`send_init_page` submission, together with FRAME migration-assessment lines for the new pallets.
The independent state check also proved that the People initialization XCM activated the Asset Hub
subscription.
Manually review the excerpt and treat panics, upgrade execution errors, failed migrations, or
essential-task failures as test failures. The excerpt is saved locally as
`<artifact-directory>/runtime-upgrade-logs.txt`. A quiet subscriber hook is not itself a failure;
the independent on-chain subscription-state check remains required.

The omni-node can also emit recurring `sub-authority-discovery` messages saying that
`AuthorityDiscoveryApi_authorities` is not exported by a parachain runtime. The latest run emitted
that same node/runtime-API compatibility noise before and after the upgrades while all state and
block-production checks passed; do not confuse it with a failed runtime migration.

### Recorded 2026-08-27 final result

After correcting the stale removed-pallet assertion and completing the explicit recovery checks,
the full default 900-second command passed and produced this aggregate advancement:

```text
relay: advanced 32733400 -> 32733550
asset-hub: advanced 19932245 -> 19932695
people: advanced 9043561 -> 9044011
bulletin: advanced 1547551 -> 1547701
Only Asset Hub and People upgraded; all four chains continued producing blocks throughout the 900-second post-upgrade observation.
```

The exact candidate hashes were Asset Hub
`61cac0c5cca1d05d834d8a1bb73ad5dac217184787c02950fcb0fde99bd6b938` and People
`4e4f915d187763d1df87263f7e5d5e4ea29999b77a8787bcdb95ec8c95a3a5ff`.

The fresh capture snapshot hashes were Relay
`36fb53c28ff62f0208fb253191ffc7e846078187fbbd167cb1cd984168e1577b`, Asset Hub
`963c9ff1d5f5c1ac4ca304f819f7ff73ddf158caa980ee410b99746e481ed35c`, People
`48ba375dd3cb1ebb1651752061bce08b8372e4633a0b3198b07fa8212c433ae9`, and Bulletin
`2e67ed06e02e3dbdca5ceab9ae3d5716590210f75a4963262b9c1a86d346888d`.

## 12. Stop the network

Run in Terminal 2:

```sh
make stop
```

Expected immediate output:

```text
./scripts/stop.sh
```

Terminal 1 can take up to approximately 90 seconds to return to the shell.

## 13. Optional shutdown check

Run in Terminal 2 after Terminal 1 exits:

```sh
for port in 9944 9945 9910 9914 9920; do
  if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "port $port is still open"
  else
    echo "port $port is closed"
  fi
done
```

Expected result:

```text
port 9944 is closed
port 9945 is closed
port 9910 is closed
port 9914 is closed
port 9920 is closed
```

## Optional Cargo cleanup

Cargo cleanup is not part of a normal test. Use it only when you need a cold build or more disk
space.

Use explicit manifest paths. Do not use `rm` or `git clean` for this procedure.

```sh
cargo clean --manifest-path /Users/theo/Projects/parity/runtimes/Cargo.toml

CARGO_TARGET_DIR=/absolute/path/to/isolated-target \
  cargo clean --manifest-path /Users/theo/Projects/parity/runtimes/Cargo.toml

cargo clean \
  --manifest-path /absolute/path/to/runtimes/integration-tests/polkadot-live-fork/upgrade-client/Cargo.toml

cargo clean --manifest-path /tmp/polkadot-zombie-bite-tools/zombie-bite/Cargo.toml
```

These commands remove compiled Rust data. They do not remove captured chain snapshots.
