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

Confirm Node.js provides the WebSocket global used by the RPC helpers:

```sh
node --version
node -p 'typeof WebSocket'
```

Use Node.js 22 or newer. The second command must print `function`.

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

The latest fresh capture completed on 2026-08-28 UTC+7 (2026-08-27 UTC) and took 3 hours 12
minutes 54 seconds, mostly waiting for Asset Hub's public peer. Capture time depends on public peer
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
  "para_1000_start_block": 19950771,
  "para_1004_start_block": 9061825,
  "para_1010_start_block": 1554250,
  "rc_start_block": 32741430
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

The latest run took 49 seconds from `make spawn` to the ready message with the explicit runtime log
filters enabled.

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
latest run it included XcmpQueue migration from version 6 to 7 on both chains, `PGAS
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

### Recorded 2026-08-28 UTC+7 final result

The normal strict upgrade path passed with recovery mode unset. The full default 900-second command
then passed and produced this aggregate advancement:

```text
relay: advanced 32741524 -> 32741674
asset-hub: advanced 19951030 -> 19951480
people: advanced 9061916 -> 9062066
bulletin: advanced 1554341 -> 1554491
Only Asset Hub and People upgraded; all four chains continued producing blocks throughout the 900-second post-upgrade observation.
```

The exact candidate hashes were Asset Hub
`7a39bcb6fe809bf81d644263a5ca870a5fa919fdc477f10228f0f235286a7f1e` and People
`fdd9c605680597f4e0b5c8e4ccc01d09d8b39321e2df773d9036b4690278292a`.

The fresh capture snapshot hashes were Relay
`882c8f94e13a8f3ac830916a27cb88b0e5f8b7c2f161e99663e27aa0084a5b10`, Asset Hub
`88c456decb4197abc707d8bfbe64173096b2a4dec4cc28f7d771ab88f06ff135`, People
`aa46ea62679405bdf97ef0f9e5d42d93c8de21cb17e47c425f2fb1be122b861b`, and Bulletin
`2f30d63796b09448321c8f87910c62efe10589d9c085a3f7d18a352183ca57d9`.

Three late formatting-only base commits changed the reproducible candidate bytes after the fresh
capture. The snapshots were restored to localhost and materialized at the same boundaries with the
final authorizations; no production peer was contacted and neither artifact-reuse control was
enabled. The resulting validation snapshot hashes were Relay
`6ffcfc0d0228086c363df3368f1d489392742191f417fc85baae33e64ea33aed`, Asset Hub
`b9d7d0fc30c0c862dea667dbbbe7e9deb9e71289ad00f127a4bb9e5f250125f3`, People
`cb440ff959c66e4bcee749ff49089fa1366962999bbe32ff8c0a41444d80b986`, and untouched Bulletin
`2f30d63796b09448321c8f87910c62efe10589d9c085a3f7d18a352183ca57d9`. The local result is retained
in `artifacts-clean-proof-stable2606-20260827-007`.

The Bash-3.2-safe optional recovery scalar remained in place. In the latest run, one shell attempt
omitted Cargo from `PATH` and stopped before launching the client or changing chain state. The
subsequent strict, chain-mutating invocation exited zero in 7 minutes 20 seconds with recovery mode
unset.

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
