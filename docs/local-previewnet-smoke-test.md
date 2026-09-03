# Local PreviewNet smoke test for PR #1233

Use this guide to reproduce a local network. The network contains the Polkadot relay chain,
People Polkadot, Asset Hub Polkadot, Bulletin, Web3 Storage, IPFS, the Web3 storage provider,
and the Asset Hub Ethereum RPC compatibility service.

This is a smoke test of the runtime that comes from `polkadot-fellows/runtimes` PR #1233. The
test proves that the selected WASMs build. It also proves that the five PreviewNet chains and the
support services run. The test does not prove compatibility with the Polkadot production
topology. It also does not prove governance bootstrap, migrations, PGAS deployment, the
NFT-credit lifecycle, or complete launch readiness.

The validated revisions are:

- runtimes integration head: `18a7466ea0a4134a6605c84e35af4958103bf732`
- compatible Individuality SDK: `4fca4f8391f1e38898cfb0803db4da5cb25db9e3`
- PreviewNet: `01bdd9b4367eb4ccb67ffa1118ef29fc82fa7766` on canonical branch
  `theo/current-runtimes-local-previewnet`

The `individuality-integration-local-testing` branch is a fork-only review surface. Do not merge
its `.gitmodules`, `preview-net-v1` gitlink, and `rust-toolchain.toml` into
`individuality-integration`. Do not cherry-pick them into the fellowship repository.

## Prerequisites

- Git with SSH access to GitHub
- Rustup
- Node.js and pnpm
- GNU Make, jq, and curl
- Enough free disk space for a full release build

The runtimes workspace uses local path dependencies from Individuality. Thus, the two
repositories must be sibling directories:

```text
workspace/
├── individuality/
└── runtimes/
```

Create that layout with:

```sh
mkdir workspace
cd workspace
git clone https://github.com/paritytech/individuality.git individuality
git -C individuality checkout 4fca4f8391f1e38898cfb0803db4da5cb25db9e3
git clone --recurse-submodules \
  --branch individuality-integration-local-testing \
  https://github.com/agustinustheo/runtimes.git runtimes
cd runtimes
```

If you cloned `runtimes` without submodules, initialize PreviewNet separately:

```sh
git submodule update --init --recursive
```

An existing checkout can point to the upstream PreviewNet URL. Before you update such a
checkout, synchronize it with the committed `.gitmodules` file:

```sh
git submodule sync --recursive
git submodule update --init --recursive
```

Make sure that a fresh checkout resolved the intended repository and commit:

```sh
git -C preview-net-v1 remote get-url origin
git -C preview-net-v1 rev-parse HEAD
```

The expected output is:

```text
git@github.com:paritytech/preview-net-v1.git
01bdd9b4367eb4ccb67ffa1118ef29fc82fa7766
```

Do not use the `individuality/main` branch, because it moves. Before each build, select the
revisions that define the smoke test. Record these revisions:

```sh
git -C ../individuality checkout 4fca4f8391f1e38898cfb0803db4da5cb25db9e3
printf 'runtimes=%s\n' "$(git rev-parse HEAD)"
printf 'individuality=%s\n' "$(git -C ../individuality rev-parse HEAD)"
printf 'preview-net=%s\n' "$(git -C preview-net-v1 rev-parse HEAD)"
```

The Individuality SHA is the last reviewed SDK architecture that is compatible with the current
Game configuration and runtime API of PR #1233. Newer Individuality revisions need changes to the
runtime. These changes do not belong on this testing branch.

## 1. Install and verify Cargo 1.93.0

The repository's `rust-toolchain.toml` pins Rust and Cargo to 1.93.0. Install the WASM tools
that the toolchain needs:

```sh
rustup toolchain install 1.93.0 \
  --profile default \
  --component rust-src \
  --target wasm32-unknown-unknown
cargo --version
rustc --version
```

The first command must report `cargo 1.93.0`. Run Cargo without a `+stable` or `+nightly`
override. This keeps the repository pin effective.

## 2. Build the complete runtimes workspace

From `runtimes/`:

```sh
cargo build --release
```

This command checks the complete workspace. It creates the compressed People, Asset Hub,
Bulletin, and relay-chain WASM artifacts. The warnings that recommend `wasm32v1-none` are
advisory. We test this branch with the pinned `wasm32-unknown-unknown` target.

## 3. Fetch PreviewNet's native dependencies

Fetch the binaries and the runtime dependencies that do not come from this workspace. These
include the Web3 Storage runtime and the storage provider:

```sh
cd preview-net-v1
make fetch
cd ..
```

Run `make fetch` before you copy the locally built runtimes. The command writes to the same
`bin/` directory.

## 4. Build the fast local relay runtime

The production relay chain epoch is too long for a useful local smoke test. After the full
release build, build Polkadot with its `fast-runtime` feature:

```sh
cargo build --release -p polkadot-runtime --features fast-runtime
```

This command shortens the first session rotation to approximately 20 relay blocks. Parachain
validator groups do not exist until that first rotation. Thus, it is normal that the parachains
stay at block zero before relay block 21.

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

Web3 Storage continues to use the compatible artifact that `make fetch` downloads.

## 6. Run all PreviewNet unit tests

```sh
cd preview-net-v1
make test-unit
cd ..
```

The validated suite contains 146 tests. All 146 tests must pass before you generate the
specifications or start the network.

## 7. Regenerate PreviewNet configuration and chain specifications

```sh
cd preview-net-v1
make generate-toml
make generate
cd ..
```

The generated configuration contains three compatibility settings that the current runtimes need:

- The relay chain nodes force WASM execution. The prebuilt node's native runtime has the
  same spec version as the local fast runtime. Forced WASM execution makes sure that the
  native runtime does not replace the fast runtime.
- The relay chain claim queue uses a lookahead of two. People and Asset Hub use relay-parent
  offset one. Thus, they need the current assignment and the next assignment.
- The Aura session keys and the keystore keys of Asset Hub use Ed25519. The local chain name of
  Asset Hub does not trigger Zombienet's built-in `asset-hub-polkadot` detection.

## 8. Start the smoke network

```sh
cd preview-net-v1
make start EPHEMERAL=1
```

Keep that terminal open. Startup usually takes approximately 80–90 seconds. In this time, the
network generates the raw chain specifications and starts the processes. Then wait two more
minutes until the relay chain reaches its first session rotation.

The RPC ports are:

| Chain | Port |
| --- | ---: |
| Polkadot relay | 10000 |
| People Polkadot | 10010 |
| Asset Hub Polkadot | 10020 |
| Bulletin | 10030 |
| Web3 Storage | 10040 |

## 9. Verify that every chain advances

In another terminal, run this command two times. Wait 15–30 seconds between the two runs:

```sh
for port in 10000 10010 10020 10030 10040; do
  printf '%s port=%s height=' "$(date -Iseconds)" "$port"
  curl -sS --max-time 3 \
    -H 'content-type: application/json' \
    --data '{"jsonrpc":"2.0","id":1,"method":"chain_getHeader","params":[]}' \
    "http://127.0.0.1:$port" |
    jq -r '.result.number // .error.message // "unavailable"'
done
```

Success requires all five hexadecimal heights to increase. The validated run produced:

```text
relay=0x18  people=0x2  asset-hub=0x2  bulletin=0x4  web3-storage=0x5
relay=0x1c  people=0x5  asset-hub=0x5  bulletin=0x8  web3-storage=0x9
```

Run the following health check for every chain. Each response must report `isSyncing: false` and
must not contain an RPC error:

```sh
for port in 10000 10010 10020 10030 10040; do
  printf 'port=%s ' "$port"
  curl -sS --max-time 3 \
    -H 'content-type: application/json' \
    --data '{"jsonrpc":"2.0","id":1,"method":"system_health","params":[]}' \
    "http://127.0.0.1:$port" | jq -c '.result // .error'
done
```

Use these commands to check the support services:

```sh
curl -X POST http://127.0.0.1:5001/api/v0/version
curl http://127.0.0.1:8080/ipfs/bafkqaaa
curl -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_chainId","params":[]}' \
  http://127.0.0.1:8545
curl -sS -o /dev/null -w 'storage-provider HTTP %{http_code}\n' \
  http://127.0.0.1:3333/
```

The Web3 storage provider listens on port 3333. A 404 response at `/` still proves that the HTTP
server listens. Check that the provider process log shows that it connected, registered on-chain,
and started the checkpoint coordinator.

## 10. Stop the network

Return to the PreviewNet terminal. Press Ctrl-C. The ephemeral network and its child processes
stop cleanly.

## Troubleshooting

- **All parachains remain at block zero while the relay chain is below block 21:** wait for the
  first fast session rotation.
- **`InvalidNumberOfDescendants` or missing `set_validation_data`:** regenerate the TOML. Make
  sure that the relay chain scheduler has `lookahead = 2`. Make sure that People and Asset Hub use
  `--authoring=slot-based`.
- **Asset Hub prepares blocks but logs `Unable to build block at slot`:** make sure that its
  collator has both `chain_spec_key_types = ["aura_ed"]` and `keystore_key_types = ["aura_ed"]`.
- **Ethereum RPC exits with `ChainMismatch`:** use the committed wrapper. The wrapper runs with
  `--eth-pruning 256`. Thus, it does not reuse a stale receipt database across ephemeral
  networks.
- **Genesis helper calls mention a missing Sudo pallet:** the current production relay chain
  runtime does not expose Sudo. This block-production smoke test does not need those optional
  core-assignment and bootstrap helpers. The registered parachains receive their base cores
  automatically.
