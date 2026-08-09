# Local PreviewNet smoke test

This guide reproduces a local network containing the Polkadot relay chain, People Polkadot,
Asset Hub Polkadot, Bulletin, Web3 Storage, IPFS, the Web3 storage provider, and the Asset Hub
Ethereum RPC compatibility service.

The tested parent branch is `individuality-integration-local-testing`. Its PreviewNet submodule
points to commit `01bdd9b4367eb4ccb67ffa1118ef29fc82fa7766`, published on PreviewNet branch
`fix/current-runtimes-local-previewnet`.

## Prerequisites

- Git with SSH access to GitHub
- Rustup
- Node.js and pnpm
- GNU Make, jq, and curl
- Enough free disk space for a full release build

The runtimes workspace uses local path dependencies from Individuality, so the two repositories
must be sibling directories:

```text
workspace/
├── individuality/
└── runtimes/
```

Create that layout with:

```sh
mkdir workspace
cd workspace
git clone --branch main git@github.com:paritytech/individuality.git individuality
git clone --recurse-submodules \
  --branch individuality-integration-local-testing \
  git@github.com:agustinustheo/runtimes.git runtimes
cd runtimes
```

If `runtimes` was cloned without submodules, initialize PreviewNet separately:

```sh
git submodule update --init --recursive
```

## 1. Install and verify Cargo 1.93.0

The repository's `rust-toolchain.toml` pins Rust and Cargo to 1.93.0. Install its required WASM
tooling explicitly:

```sh
rustup toolchain install 1.93.0 \
  --profile default \
  --component rust-src \
  --target wasm32-unknown-unknown
cargo --version
rustc --version
```

The first command should report `cargo 1.93.0`. Run Cargo without a `+stable` or `+nightly`
override so the repository pin remains effective.

## 2. Build the complete runtimes workspace

From `runtimes/`:

```sh
cargo build --release
```

This verifies the complete workspace and creates the compressed People, Asset Hub, Bulletin, and
relay-chain WASM artifacts. Warnings recommending `wasm32v1-none` are advisory; this branch is
tested with the pinned `wasm32-unknown-unknown` target.

## 3. Fetch PreviewNet's native dependencies

Fetch binaries and the runtime dependencies that do not come from this workspace, including the
Web3 Storage runtime and storage provider:

```sh
cd preview-net-v1
make fetch
cd ..
```

Run `make fetch` before copying the locally built runtimes because it populates the same `bin/`
directory.

## 4. Build the fast local relay runtime

The production relay epoch is too long for a useful local smoke test. Build Polkadot with its
`fast-runtime` feature after the full release build:

```sh
cargo build --release -p polkadot-runtime --features fast-runtime
```

This shortens the first session rotation to approximately 20 relay blocks. Parachain validator
groups do not exist until that first rotation, so parachains remaining at block zero before relay
block 21 is expected.

## 5. Install the locally built WASM files into PreviewNet

From `runtimes/`:

```sh
cp target/release/wbuild/polkadot-runtime/polkadot_runtime.compact.compressed.wasm \
  preview-net-v1/bin/paseo_runtime.wasm
cp target/release/wbuild/people-polkadot-runtime/people_polkadot_runtime.compact.compressed.wasm \
  preview-net-v1/bin/next_people_paseo_runtime.wasm
cp target/release/wbuild/asset-hub-polkadot-runtime/asset_hub_polkadot_runtime.compact.compressed.wasm \
  preview-net-v1/bin/next_asset_hub_paseo_runtime.wasm
cp target/release/wbuild/bulletin-polkadot-runtime/bulletin_polkadot_runtime.compact.compressed.wasm \
  preview-net-v1/bin/bulletin_paseo_runtime.wasm
```

Web3 Storage continues to use the compatible artifact downloaded by `make fetch`.

## 6. Regenerate PreviewNet configuration and chain specifications

```sh
cd preview-net-v1
make generate-toml
make generate
```

The generated configuration contains three compatibility settings needed by the current runtimes:

- Relay nodes force WASM execution, preventing the prebuilt node's native runtime from shadowing
  the locally built fast runtime with the same spec version.
- The relay claim queue uses a lookahead of two. People and Asset Hub use relay-parent offset one,
  so they need both the current and next assignments.
- Asset Hub's Aura session and keystore keys explicitly use Ed25519. Its local chain name does not
  trigger Zombienet's built-in `asset-hub-polkadot` detection.

## 7. Start the smoke network

```sh
make start EPHEMERAL=1
```

Keep that terminal open. Startup normally spends roughly 80–90 seconds generating raw chain
specifications and launching processes. Allow another two minutes for the relay to reach its first
session rotation.

The RPC ports are:

| Chain | Port |
| --- | ---: |
| Polkadot relay | 10000 |
| People Polkadot | 10010 |
| Asset Hub Polkadot | 10020 |
| Bulletin | 10030 |
| Web3 Storage | 10040 |

## 8. Verify that every chain advances

In another terminal, run this twice with a 15–30 second gap:

```sh
for port in 10000 10010 10020 10030 10040; do
  printf '%s=' "$port"
  curl -sS --max-time 3 \
    -H 'content-type: application/json' \
    --data '{"jsonrpc":"2.0","id":1,"method":"chain_getHeader","params":[]}' \
    "http://127.0.0.1:$port" |
    jq -r '.result.number // .error.message // "unavailable"'
done
```

Success means all five hexadecimal heights increase. The validated run produced:

```text
relay=0x18  people=0x2  asset-hub=0x2  bulletin=0x4  web3-storage=0x5
relay=0x1c  people=0x5  asset-hub=0x5  bulletin=0x8  web3-storage=0x9
```

Check the supporting services with:

```sh
curl -X POST http://127.0.0.1:5001/api/v0/version
curl http://127.0.0.1:8080/ipfs/bafkqaaa
curl -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}' \
  http://127.0.0.1:8545
```

The Web3 storage provider listens on port 3333. A 404 response at `/` still proves the HTTP server
is listening; its process log should also say that it connected, registered on-chain, and started
the checkpoint coordinator.

## 9. Stop the network

Return to the PreviewNet terminal and press Ctrl-C. The ephemeral network and its child processes
should exit cleanly.

## Troubleshooting

- **All parachains remain at block zero while relay is below block 21:** wait for the first fast
  session rotation.
- **`InvalidNumberOfDescendants` or missing `set_validation_data`:** regenerate the TOML and confirm
  the relay scheduler has `lookahead = 2` and People/Asset Hub use `--authoring=slot-based`.
- **Asset Hub prepares blocks but logs `Unable to build block at slot`:** confirm its collator has
  both `chain_spec_key_types = ["aura_ed"]` and `keystore_key_types = ["aura_ed"]`.
- **Ethereum RPC exits with `ChainMismatch`:** use the committed wrapper, which runs with
  `--eth-pruning 256` and therefore does not reuse a stale receipt database across ephemeral
  networks.
- **Genesis helper calls mention a missing Sudo pallet:** the current production relay runtime does
  not expose Sudo. Those optional core-assignment and bootstrap helpers are not required for this
  block-production smoke test; the registered parachains receive their base cores automatically.

