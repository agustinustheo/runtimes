# Polkadot live-state fork with Zombie Bite

This harness forks live Polkadot state from `wss://polkadot-rpc.publicnode.com` and attaches live-state forks of Asset Hub (1000), People (1004), and Bulletin (1010). The three parachains run the runtime artifacts built from this runtimes checkout.

Zombie Bite and Doppelganger are pinned in `versions.env`. A small pinned patch makes Zombie Bite honor the configured relay RPC and provides a distinct fixed RPC port for every parachain. Generated state, chain specs, and logs are ignored by Git.
Setup exposes the relay Doppelganger under the `polkadot` command emitted by Zombie Bite's spawn config. Parachains spawn with the current SDK `preview-net-v1/bin/polkadot-omni-node`; override `PARACHAIN_NODE_BIN` if that binary lives elsewhere. Asset Hub bites default to archive-canonical state pruning while the relay and other parachains retain Zombie Bite's `256` default. This keeps Asset Hub's live canonical state while avoiding the oversized RocksDB pruning journal that macOS cannot read when its initial state import exceeds 2 GiB.

Successful bites discard Zombie Bite's large intermediate debug directory after the spawn artifacts are safely assembled. Set `ZOMBIE_BITE_KEEP_DEBUG=1` to retain it when diagnosing a failed fork.
Interrupted bites can be rerun in place: validated parachain snapshots are reused, while an incomplete relay database resumes from its last imported state.

## Run

The default runtime artifact directory is the primary runtimes checkout's `target`. Override `RUNTIMES_TARGET_DIR`, or any individual `*_WASM` variable, when needed.

```sh
cd integration-tests/polkadot-live-fork
make bite
make spawn
```

Keep `make spawn` running. From another shell:

```sh
make verify-fork
make verify
make stop
```

You can run `make verify` immediately after `make spawn`. Startup is sequential and can take a few minutes, so verification waits up to five minutes for all four RPCs instead of treating an RPC that has not spawned yet as a failed chain. Override the wait with `VERIFY_STARTUP_TIMEOUT_MS` when needed.

Run `make verify-fork` first when you want to establish provenance independently of candidate-runtime and block-production checks. At each block recorded in `artifacts/ready.json`, it compares the local boundary header with the current canonical header returned by the configured live RPC. The genesis hash, block number, canonical parent hash, extrinsics root, and consensus digest must match. The boundary block hash and state root may differ because Zombie Bite deliberately rewrites state to install runtime and authority overrides.

New bites default to relay `9944`, Asset Hub `9910`, People `9914`, and Bulletin `9920`. The actual ports are recorded in `artifacts/ports.json`, which `make verify` reads before requiring all four endpoints to advance over 24 seconds.

## Boundary

This proves that the selected relay and parachain state was copied from live RPCs, the candidate runtimes were injected, the parachains were registered in the local relay state, and all four chains produce blocks locally. It does not by itself prove a production upgrade, external client compatibility, or successful application-level XCM messages. Those require explicit scenario transactions after startup.
