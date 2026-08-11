import { readFile } from "node:fs/promises";
import path from "node:path";
import { rpc, waitForRpc, hexBlockNumber } from "./rpc.mjs";

if (!process.env.ARTIFACTS_DIR) throw new Error("ARTIFACTS_DIR is not set");
const ports = JSON.parse(
  await readFile(path.join(process.env.ARTIFACTS_DIR, "ports.json"), "utf8"),
);

const endpoints = [
  ["relay", `ws://127.0.0.1:${ports.alice_port}`],
  ["asset-hub", `ws://127.0.0.1:${ports.para_1000_collator_port}`],
  ["people", `ws://127.0.0.1:${ports.para_1004_collator_port}`],
  ["bulletin", `ws://127.0.0.1:${ports.para_1010_collator_port}`],
];
const relayEndpoint = endpoints[0][1];
const runtimeArtifacts = [
  ["asset-hub", endpoints[1][1], process.env.ASSET_HUB_WASM],
  ["people", endpoints[2][1], process.env.PEOPLE_WASM],
  ["bulletin", endpoints[3][1], process.env.BULLETIN_WASM],
];

const startupTimeoutMs = Number.parseInt(
  process.env.VERIFY_STARTUP_TIMEOUT_MS ?? "300000",
  10,
);
if (!Number.isSafeInteger(startupTimeoutMs) || startupTimeoutMs <= 0) {
  throw new Error("VERIFY_STARTUP_TIMEOUT_MS must be a positive integer");
}

console.log(
  `waiting up to ${Math.round(startupTimeoutMs / 1_000)}s for all four local RPCs...`,
);
await Promise.all(
  endpoints.map(async ([name, endpoint]) => {
    await waitForRpc(endpoint, startupTimeoutMs);
    console.log(`${name}: RPC ready at ${endpoint}`);
  }),
);

const parasStorageKey =
  "0xcd710b30bd2eab0352ddcc26417aa1940b76934f4cc08dee01012d059e1b83ee";

function decodeU32Vector(encoded) {
  const bytes = Buffer.from(encoded.slice(2), "hex");
  if ((bytes[0] & 3) !== 0) throw new Error("Unexpected compact length encoding");
  const length = bytes[0] >> 2;
  return Array.from({ length }, (_, index) => bytes.readUInt32LE(1 + index * 4));
}

const registeredParas = decodeU32Vector(
  await rpc(relayEndpoint, "state_getStorage", [parasStorageKey]),
);
for (const expected of [1000, 1004, 1010]) {
  if (!registeredParas.includes(expected)) {
    throw new Error(`relay is missing parachain ${expected}: ${registeredParas.join(", ")}`);
  }
}
console.log(`relay registered parachains: ${registeredParas.join(", ")}`);

for (const [name, endpoint, artifactPath] of runtimeArtifacts) {
  if (!artifactPath) throw new Error(`${name} runtime artifact path is not set`);
  const [expectedCode, storedCodeHex] = await Promise.all([
    readFile(artifactPath),
    rpc(endpoint, "state_getStorage", ["0x3a636f6465"]),
  ]);
  const storedCode = Buffer.from(storedCodeHex.slice(2), "hex");
  if (!storedCode.equals(expectedCode)) {
    throw new Error(`${name} is not running the configured runtime artifact`);
  }
  console.log(`${name}: candidate runtime matches (${storedCode.length} bytes)`);
}

const before = new Map();
for (const [name, endpoint] of endpoints) {
  const [chain, header] = await Promise.all([
    rpc(endpoint, "system_chain"),
    rpc(endpoint, "chain_getHeader"),
  ]);
  const number = hexBlockNumber(header);
  before.set(name, number);
  console.log(`${name}: ${chain}, initial local block ${number}`);
}

await new Promise((resolve) => setTimeout(resolve, 24_000));

for (const [name, endpoint] of endpoints) {
  const number = hexBlockNumber(await rpc(endpoint, "chain_getHeader"));
  const initial = before.get(name);
  if (number <= initial) throw new Error(`${name} stalled at block ${number}`);
  console.log(`${name}: advanced ${initial} -> ${number}`);
}

console.log("All four forked chains are reachable and producing blocks.");
