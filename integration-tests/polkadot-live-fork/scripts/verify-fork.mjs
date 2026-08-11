import { readFile } from "node:fs/promises";
import path from "node:path";
import { rpc, waitForRpc } from "./rpc.mjs";

if (!process.env.ARTIFACTS_DIR) throw new Error("ARTIFACTS_DIR is not set");

const [ready, ports] = await Promise.all(
  ["ready.json", "ports.json"].map(async (name) =>
    JSON.parse(await readFile(path.join(process.env.ARTIFACTS_DIR, name), "utf8")),
  ),
);

const chains = [
  {
    name: "relay",
    live: process.env.RELAY_RPC,
    local: `ws://127.0.0.1:${ports.alice_port}`,
    block: ready.rc_start_block,
  },
  {
    name: "asset-hub",
    live: process.env.ASSET_HUB_RPC,
    local: `ws://127.0.0.1:${ports.para_1000_collator_port}`,
    block: ready.para_1000_start_block,
  },
  {
    name: "people",
    live: process.env.PEOPLE_RPC,
    local: `ws://127.0.0.1:${ports.para_1004_collator_port}`,
    block: ready.para_1004_start_block,
  },
  {
    name: "bulletin",
    live: process.env.BULLETIN_RPC,
    local: `ws://127.0.0.1:${ports.para_1010_collator_port}`,
    block: ready.para_1010_start_block,
  },
];

for (const chain of chains) {
  if (!chain.live) throw new Error(`${chain.name}: live RPC is not configured`);
  if (!Number.isSafeInteger(chain.block)) {
    throw new Error(`${chain.name}: capture block is missing from ready.json`);
  }
}

async function rpcWithRetry(endpoint, method, params = [], attempts = 5) {
  let lastError;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      return await rpc(endpoint, method, params);
    } catch (error) {
      lastError = error;
      if (attempt < attempts) {
        await new Promise((resolve) => setTimeout(resolve, attempt * 1_000));
      }
    }
  }
  throw lastError;
}

function requireEqual(chain, field, liveValue, localValue) {
  if (JSON.stringify(liveValue) !== JSON.stringify(localValue)) {
    throw new Error(
      `${chain}: fork boundary ${field} differs\n` +
        `  live:  ${JSON.stringify(liveValue)}\n` +
        `  local: ${JSON.stringify(localValue)}`,
    );
  }
}

console.log("Checking recorded bite boundaries against the configured live RPCs...");

for (const chain of chains) {
  await Promise.all([waitForRpc(chain.live), waitForRpc(chain.local)]);

  const [liveGenesis, localGenesis, liveHash, localHash, liveParentHash] = await Promise.all([
    rpcWithRetry(chain.live, "chain_getBlockHash", [0]),
    rpcWithRetry(chain.local, "chain_getBlockHash", [0]),
    rpcWithRetry(chain.live, "chain_getBlockHash", [chain.block]),
    rpcWithRetry(chain.local, "chain_getBlockHash", [chain.block]),
    rpcWithRetry(chain.live, "chain_getBlockHash", [chain.block - 1]),
  ]);

  if (!liveHash || !localHash || !liveParentHash) {
    throw new Error(`${chain.name}: block history is unavailable at ${chain.block}`);
  }

  const [liveHeader, localHeader] = await Promise.all([
    rpcWithRetry(chain.live, "chain_getHeader", [liveHash]),
    rpcWithRetry(chain.local, "chain_getHeader", [localHash]),
  ]);

  requireEqual(chain.name, "genesis hash", liveGenesis, localGenesis);
  requireEqual(chain.name, "block number", liveHeader.number, localHeader.number);
  requireEqual(chain.name, "canonical parent hash", liveParentHash, localHeader.parentHash);
  requireEqual(chain.name, "parent hash", liveHeader.parentHash, localHeader.parentHash);
  requireEqual(chain.name, "extrinsics root", liveHeader.extrinsicsRoot, localHeader.extrinsicsRoot);
  requireEqual(chain.name, "consensus digest", liveHeader.digest, localHeader.digest);

  console.log(`${chain.name}: live fork boundary confirmed at block ${chain.block}`);
  console.log(`  live canonical hash: ${liveHash}`);
  console.log(`  local rewritten hash: ${localHash}`);
  console.log(`  canonical parent:     ${liveParentHash}`);
  if (liveHeader.stateRoot !== localHeader.stateRoot) {
    console.log("  state root rewritten as expected for runtime/authority overrides");
  } else {
    console.log("  state root unchanged at the fork boundary");
  }
}

console.log("All four local chains retain their recorded live-chain fork boundaries.");
