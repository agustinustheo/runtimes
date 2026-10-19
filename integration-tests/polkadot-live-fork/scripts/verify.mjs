import { readFile, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";
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
  [
    "asset-hub",
    endpoints[1][1],
    process.env.ASSET_HUB_WASM,
    Number(process.env.ASSET_HUB_LIVE_SPEC_VERSION),
  ],
  [
    "people",
    endpoints[2][1],
    process.env.PEOPLE_WASM,
    Number(process.env.PEOPLE_LIVE_SPEC_VERSION),
  ],
];
const authorizedUpgradeKey =
  "0x26aa394eea5630e07c48ae0c9558cef72fa9f1bf25567808771bff091dc89ecd";
const peopleSubscriberKey =
  "0xeed2209ef3b09989cb5b7851e0245754cb128dde8c9456194d7ea2f66ef6dc52e8030000";
const peoplePendingInitKey =
  "0xeed2209ef3b09989cb5b7851e0245754b67d2cb81868e2929e11aebd249d84d3e8030000";
const peopleToAssetHubChannelKey =
  "0x6a0da05ca59913bc38a8630590f2627cb6604cff828a6e3f579ca6c59ace013d98ebe6f3ad4dcc3aec030000e8030000";
const assetHubIngressIndexKey =
  "0x6a0da05ca59913bc38a8630590f2627c1d3719f5b0b12c7105c073c507445948b6ff6f7d467b87a9e8030000";
const peopleEgressIndexKey =
  "0x6a0da05ca59913bc38a8630590f2627cf12b746dcf32e843354583c9702cc020cafa6fcc550ffd86ec030000";
const lastHrmpMqcHeadsKey =
  "0x45323df7cc47150b3930e2666b0aa3133dca42deb008c6559ee789c9b9f70a2c";

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

function decodeMqcHead(encoded, sender) {
  const bytes = Buffer.from(encoded.slice(2), "hex");
  if ((bytes[0] & 3) !== 0) throw new Error("Unexpected MQC map length encoding");
  const length = bytes[0] >> 2;
  for (let index = 0; index < length; index += 1) {
    const offset = 1 + index * 36;
    if (bytes.readUInt32LE(offset) === sender) {
      return bytes.subarray(offset + 4, offset + 36).toString("hex");
    }
  }
  throw new Error(`Asset Hub MQC history has no sender ${sender}`);
}

const [peopleToAssetHubChannel, assetHubIngress, peopleEgress, assetHubMqcHeads] =
  await Promise.all([
    rpc(relayEndpoint, "state_getStorage", [peopleToAssetHubChannelKey]),
    rpc(relayEndpoint, "state_getStorage", [assetHubIngressIndexKey]),
    rpc(relayEndpoint, "state_getStorage", [peopleEgressIndexKey]),
    rpc(endpoints[1][1], "state_getStorage", [lastHrmpMqcHeadsKey]),
  ]);
if (!peopleToAssetHubChannel || !assetHubMqcHeads) {
  throw new Error("missing live People-to-Asset-Hub HRMP channel state");
}
if (assetHubIngress !== "0x04ec030000" || peopleEgress !== "0x04e8030000") {
  throw new Error("People-to-Asset-Hub HRMP indexes are not isolated to the test channel");
}
const peopleMqcHead = decodeMqcHead(assetHubMqcHeads, 1004);
if (!peopleToAssetHubChannel.includes(peopleMqcHead)) {
  throw new Error("relay HRMP channel head does not match Asset Hub's captured MQC head");
}
console.log(`relay retained live People-to-Asset-Hub HRMP head 0x${peopleMqcHead}`);

for (const [name, endpoint, artifactPath, expectedSpecVersion] of runtimeArtifacts) {
  if (!artifactPath) throw new Error(`${name} runtime artifact path is not set`);
  const [candidateCode, storedCodeHex, runtimeVersion, authorization] = await Promise.all([
    readFile(artifactPath),
    rpc(endpoint, "state_getStorage", ["0x3a636f6465"]),
    rpc(endpoint, "state_getRuntimeVersion"),
    rpc(endpoint, "state_getStorage", [authorizedUpgradeKey]),
  ]);
  const storedCode = Buffer.from(storedCodeHex.slice(2), "hex");
  if (storedCode.equals(candidateCode)) {
    throw new Error(`${name} already runs the candidate; expected an original live runtime`);
  }
  if (runtimeVersion.specVersion !== expectedSpecVersion) {
    throw new Error(
      `${name}: expected original live spec_version ${expectedSpecVersion}, got ${runtimeVersion.specVersion}`,
    );
  }
  if (!authorization) {
    throw new Error(`${name}: missing injected System.AuthorizedUpgrade`);
  }
  console.log(
    `${name}: original live runtime ${runtimeVersion.specVersion}; candidate authorization present`,
  );
}

const peopleEndpoint = endpoints[2][1];
const [subscriberFixture, pendingInitFixture] = await Promise.all([
  rpc(peopleEndpoint, "state_getStorage", [peopleSubscriberKey]),
  rpc(peopleEndpoint, "state_getStorage", [peoplePendingInitKey]),
]);
if (!subscriberFixture || !pendingInitFixture) {
  throw new Error("People: missing pre-seeded Asset Hub notifier subscription fixture");
}
console.log("people: pending Asset Hub notifier initialization fixture present");

const baseline = {};
for (const [name, endpoint] of endpoints) {
  const [runtimeVersion, codeHex] = await Promise.all([
    rpc(endpoint, "state_getRuntimeVersion"),
    rpc(endpoint, "state_getStorage", ["0x3a636f6465"]),
  ]);
  baseline[name] = {
    specVersion: runtimeVersion.specVersion,
    codeSha256: createHash("sha256")
      .update(Buffer.from(codeHex.slice(2), "hex"))
      .digest("hex"),
  };
}
await writeFile(
  path.join(process.env.ARTIFACTS_DIR, "upgrade-baseline.json"),
  `${JSON.stringify(baseline, null, 2)}\n`,
);
console.log("recorded pre-upgrade runtime baseline");

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

console.log("All four original-runtime forks are reachable and producing blocks.");
