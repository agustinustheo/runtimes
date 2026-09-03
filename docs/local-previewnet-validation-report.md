# Local PreviewNet validation report

This report records the commands and the results from the nine-step local PreviewNet validation. We did the validation on 10 August 2026. For the build and startup procedure on a fresh machine, see [Local PreviewNet smoke test for PR #1233](./local-previewnet-smoke-test.md).

## Tested environment

- PreviewNet commit: `01bdd9b4367eb4ccb67ffa1118ef29fc82fa7766`
- Startup command: `make start EPHEMERAL=1`
- Host: macOS 15.7.7 on Apple Silicon
- Rust toolchain: `rustc 1.93.0`
- Test window: 2026-08-10 11:49-11:50 UTC+7
- Overall result: **PASS**

Run the commands while the network runs. Before you run the commands, install `curl`, `jq`, Node.js, and the dependencies in `scripts/package.json`.

```bash
cd /Users/theo/Projects/parity/runtimes/preview-net-v1
```

| Component | Local endpoint |
| --- | --- |
| Relay chain | `ws://127.0.0.1:10000` |
| People chain | `ws://127.0.0.1:10010` |
| Asset Hub | `ws://127.0.0.1:10020` |
| Bulletin chain | `ws://127.0.0.1:10030` |
| Web3 Storage chain | `ws://127.0.0.1:10040` |
| Asset Hub Ethereum RPC | `http://127.0.0.1:8545` |
| Storage provider | `http://127.0.0.1:3333` |
| IPFS API | `http://127.0.0.1:5001` |
| IPFS gateway | `http://127.0.0.1:8080` |

These are local `ws://` and `http://` endpoints. The local setup does not configure TLS. Thus, the endpoints are not `wss://` endpoints.

## 1. Check chain identity, health, head, and runtime

```bash
payload='[
  {"jsonrpc":"2.0","id":1,"method":"system_chain","params":[]},
  {"jsonrpc":"2.0","id":2,"method":"system_health","params":[]},
  {"jsonrpc":"2.0","id":3,"method":"chain_getHeader","params":[]},
  {"jsonrpc":"2.0","id":4,"method":"state_getRuntimeVersion","params":[]}
]'

for entry in \
  relay:10000 \
  people:10010 \
  asset-hub:10020 \
  bulletin:10030 \
  web3-storage:10040
do
  label=${entry%%:*}
  port=${entry##*:}
  printf '%s: ' "$label"

  curl -sS \
    -H 'content-type: application/json' \
    --data "$payload" \
    "http://127.0.0.1:$port" |
    jq -c 'sort_by(.id) | {
      chain: .[0].result,
      health: .[1].result,
      head: .[2].result.number,
      runtime: {
        specName: .[3].result.specName,
        specVersion: .[3].result.specVersion
      }
    }'
done
```

Observed results:

| Chain | Identity | Peers | Syncing | Head | Runtime |
| --- | --- | ---: | --- | --- | --- |
| Relay | Paseo Local | 9 | No | `0x678` | `polkadot@2003002` |
| People | Individuality Local | 0 | No | `0x5bf` | `people-polkadot@2003002` |
| Asset Hub | Asset Hub Local | 0 | No | `0x5bf` | `statemint@2003002` |
| Bulletin | Bulletin Local | 0 | No | `0x5ff` | `bulletin-polkadot@2003002` |
| Web3 Storage | Web3 Storage Local | 0 | No | `0x614` | `paseo-web3-storage-runtime@4001` |

Result: **PASS**. Zero parachain peers is normal in this single-collator topology. Each parachain reports `shouldHavePeers: false` and continues to produce blocks.

## 2. Prove every chain is advancing

```bash
snapshot() {
  date -Iseconds

  for entry in \
    relay:10000 \
    people:10010 \
    asset-hub:10020 \
    bulletin:10030 \
    web3-storage:10040
  do
    label=${entry%%:*}
    port=${entry##*:}
    printf '%s=' "$label"

    curl -sS \
      -H 'content-type: application/json' \
      --data '{"jsonrpc":"2.0","id":1,"method":"chain_getHeader","params":[]}' \
      "http://127.0.0.1:$port" |
      jq -r '.result.number'
  done
}

snapshot
sleep 15
snapshot
```

Observed results:

```text
2026-08-10T11:49:31+07:00
relay=0x679
people=0x5c0
asset-hub=0x5c0
bulletin=0x600
web3-storage=0x615

2026-08-10T11:49:46+07:00
relay=0x67b
people=0x5c2
asset-hub=0x5c2
bulletin=0x602
web3-storage=0x617
```

Result: **PASS**. All five heads advanced by two blocks in 15 seconds.

## 3. Read each chain's latest block

```bash
for entry in \
  relay:10000 \
  people:10010 \
  asset-hub:10020 \
  bulletin:10030 \
  web3-storage:10040
do
  label=${entry%%:*}
  port=${entry##*:}
  printf '%s: ' "$label"

  curl -sS \
    -H 'content-type: application/json' \
    --data '{"jsonrpc":"2.0","id":1,"method":"chain_getBlock","params":[]}' \
    "http://127.0.0.1:$port" |
    jq -c '{
      number: .result.block.header.number,
      parentHash: .result.block.header.parentHash,
      stateRoot: .result.block.header.stateRoot,
      extrinsics: (.result.block.extrinsics | length)
    }'
done
```

Observed results:

| Chain | Block | Extrinsics |
| --- | --- | ---: |
| Relay | `0x67d` | 2 |
| People | `0x5c3` | 2 |
| Asset Hub | `0x5c3` | 2 |
| Bulletin | `0x603` | 2 |
| Web3 Storage | `0x618` | 2 |

Result: **PASS**. Every chain returned a complete block with a parent hash, a state root, and extrinsics.

## 4. Check the Asset Hub Ethereum RPC

```bash
for method in \
  web3_clientVersion \
  eth_chainId \
  eth_blockNumber \
  eth_syncing
do
  printf '%s: ' "$method"

  curl -sS \
    -H 'content-type: application/json' \
    --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"$method\",\"params\":[]}" \
    http://127.0.0.1:8545 |
    jq -c '.result // .error'
done
```

Observed results:

```text
web3_clientVersion: "eth-rpc/master-cde8a92/aarch64-apple-darwin/rustc1.93.0"
eth_chainId: "0x190f1b43"
eth_blockNumber: "0x5c3"
eth_syncing: null
```

Result: **PASS with a presentation caveat**. The service returned the expected chain ID, and its block number matched Asset Hub at `0x5c3`. The captured `eth_syncing` value appears as `null` because of the jq `//` operator. The operator treats a valid JSON `false` value as absent. Then it falls through to the missing `.error` field.

To keep `false` in future runs, replace the jq expression with `if has("result") then .result else .error end`.

## 5. Check the Bulletin HOP pool

```bash
curl -sS \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"hop_poolStatus","params":[]}' \
  http://127.0.0.1:10030 |
  jq
```

Observed result:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "entryCount": 0,
    "totalBytes": 0,
    "maxBytes": 10737418240
  }
}
```

Result: **PASS**. The RPC was available, and the empty pool reported a 10 GiB capacity.

## 6. Check IPFS and perform a write/read round trip

Read the IPFS version and peer identity:

```bash
curl -sS -X POST http://127.0.0.1:5001/api/v0/version | jq
curl -sS -X POST http://127.0.0.1:5001/api/v0/id | jq '{ID, Addresses}'
```

Write a small file. Pin it. Then retrieve it through the gateway:

```bash
cid=$(
  printf 'PreviewNet IPFS smoke test at %s\n' "$(date -Iseconds)" |
    curl -sS -X POST \
      -F 'file=@-;filename=smoke.txt' \
      'http://127.0.0.1:5001/api/v0/add?pin=true' |
    jq -r '.Hash'
)

echo "CID=$cid"
curl -fsS "http://127.0.0.1:8080/ipfs/$cid"
```

Observed results:

```text
IPFS version: 0.39.0
Peer ID: 12D3KooWCbkDtJ4fPoayie56aLmdLRdxovNUN4GBq2LgSWNrTGc2
CID=QmVASRxb3qrcNzyqSR3s3f4FuctCissXAkfXQcp1VTBcRm
PreviewNet IPFS smoke test at 2026-08-10T11:50:25+07:00
```

Result: **PASS**. The gateway returned the exact content that we uploaded through the API.

This step writes and pins a small object in the disposable local IPFS repository.

## 7. Check the Web3 Storage provider

```bash
curl -sS http://127.0.0.1:3333/health | jq
curl -sS http://127.0.0.1:3333/stats | jq
```

Observed results:

```json
{
  "status": "healthy",
  "version": "0.4.1"
}
```

```json
{
  "provider_id": "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY",
  "total_buckets": 0,
  "total_nodes": 0,
  "total_bytes": 0,
  "buckets": []
}
```

Result: **PASS**. The provider was healthy. Empty bucket statistics are normal before you submit an application-level storage flow.

## 8. Submit and finalize a signed extrinsic on every chain

Warning: never use the `//Alice` key on a public or valuable network. This step submits one paid `system.remark` from the local Alice development account to each chain. Then it waits for finalization.

```bash
for WS in \
  ws://127.0.0.1:10000 \
  ws://127.0.0.1:10010 \
  ws://127.0.0.1:10020 \
  ws://127.0.0.1:10030 \
  ws://127.0.0.1:10040
do
  WS="$WS" node <<'NODE'
const { ApiPromise, WsProvider } =
  require('./scripts/node_modules/@polkadot/api');
const { Keyring } =
  require('./scripts/node_modules/@polkadot/keyring');
const { cryptoWaitReady } =
  require('./scripts/node_modules/@polkadot/util-crypto');
const { stringToHex } =
  require('./scripts/node_modules/@polkadot/util');

(async () => {
  await cryptoWaitReady();

  const endpoint = process.env.WS;
  const api = await ApiPromise.create({
    provider: new WsProvider(endpoint),
    noInitWarn: true
  });

  const alice = new Keyring({ type: 'sr25519' }).addFromUri('//Alice');
  const chain = (await api.rpc.system.chain()).toString();
  const before = await api.query.system.account(alice.address);

  const tx = api.tx.system.remark(
    stringToHex(`PreviewNet smoke test ${new Date().toISOString()}`)
  );

  let unsubscribe = () => {};

  const finalized = new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      unsubscribe();
      reject(new Error('Timed out waiting for finalization'));
    }, 90000);

    tx.signAndSend(alice, ({ status, dispatchError, txHash }) => {
      if (dispatchError) {
        clearTimeout(timer);
        unsubscribe();

        let message = dispatchError.toString();

        if (dispatchError.isModule) {
          const decoded = api.registry.findMetaError(dispatchError.asModule);
          message = `${decoded.section}.${decoded.name}`;
        }

        reject(new Error(message));
        return;
      }

      if (status.isFinalized) {
        clearTimeout(timer);

        console.log(JSON.stringify({
          endpoint,
          chain,
          txHash: txHash.toHex(),
          finalizedBlock: status.asFinalized.toHex(),
          previousNonce: before.nonce.toString()
        }));

        unsubscribe();
        resolve();
      }
    }).then((fn) => {
      unsubscribe = fn;
    }).catch(reject);
  });

  await finalized;
  await api.disconnect();
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
NODE
done
```

Observed results:

| Chain | Transaction hash | Finalized block | Previous nonce |
| --- | --- | --- | ---: |
| Paseo Local | `0x8ae155805c4bdc1b2b65424b6d4e7cd00478e420b4e3619312faf6f8f1a5d753` | `0x5630da76047521209598e592f91bc4f6bb533d7a302ee12b37a9086db5bba2b1` | 0 |
| Individuality Local | `0x43888572321b0e82573f0c3d030ec090419d6fef16f117f6ef968f95224b6187` | `0xda75238d9532eaeb51a920202383641d3d60c6aec24f16cc2fd6f45ea4fddcbe` | 0 |
| Asset Hub Local | `0x1949eb3ccd1f716a46de2c101e75887bc0a6c6dcbf0eebe1df2d871665da0462` | `0x7c606074440d3bca416bb59034406661e3b1389d9403c0be44e7611e775a96e5` | 0 |
| Bulletin Local | `0xeb9b6128eabe80f46929c9d5fee15a9a639d5152ce6461b50d9d6874ed55b17e` | `0x9f4af8c394f1b9909455a13811a8784ba76623300df3c18eca603f54c71513f8` | 0 |
| Web3 Storage Local | `0x6903ae6bd7d5ff502c54adb1ce16d100995cb57d764206be4094db8681979a32` | `0xb569f54928bfc32b2d792ed29b4120b4ec681f5aca4031cb0a4e6bbddaf7c340` | 1 |

Result: **PASS**. Every chain accepts and finalizes a signed remark. The start nonce of 1 on Web3 Storage shows that Alice has already sent one transaction there. This is not an error.

This step changes the disposable local chain state. It uses one Alice nonce on each chain.

## 9. Scan the active Zombienet logs for fatal patterns

```bash
run_dir=$(
  find /var/folders \
    -maxdepth 5 \
    -type d \
    -name 'zombie-*' \
    -exec stat -f '%m %N' {} \; 2>/dev/null |
    sort -nr |
    head -1 |
    cut -d' ' -f2-
)

echo "$run_dir"

rg -n -i \
  'panic|missing inherent|candidate validation|unable to build block|InvalidNumberOfDescendants|ChainMismatch' \
  "$run_dir" \
  -g '*.log' ||
  echo 'No fatal smoke-test patterns found'
```

Observed results:

```text
/var/folders/4l/q1m8nhw10wl6pjvlb_90lmjc0000gn/T/zombie-cf43c1e9-d974-4eea-810f-363e8f5d23c9
No fatal smoke-test patterns found
```

Result: **PASS**.

## Overall assessment

All nine smoke-test steps passed:

1. All expected RPC endpoints, chain identities, and runtimes were available.
2. All five chains continue to produce blocks.
3. Complete block data was readable from every chain.
4. The Ethereum compatibility service returned the expected chain ID and tracked Asset Hub. Step 4 explains the captured `eth_syncing` presentation.
5. The Bulletin HOP RPC was available.
6. IPFS API, pinning, and gateway retrieval worked end to end.
7. The Web3 Storage provider reported healthy.
8. A signed extrinsic finalized successfully on every chain.
9. No selected fatal patterns appeared in the active Zombienet logs.

This validation establishes infrastructure health and the basic transaction path. It does not replace application-level tests of HOP submission and claims, storage bucket creation, XCM transfers, restart persistence, or validator-failure recovery.
