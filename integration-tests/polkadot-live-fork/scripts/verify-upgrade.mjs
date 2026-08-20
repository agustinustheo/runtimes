import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { hexBlockNumber, rpc, waitForRpc } from "./rpc.mjs";

const ports = JSON.parse(
  await readFile(path.join(process.env.ARTIFACTS_DIR, "ports.json"), "utf8"),
);
const baseline = JSON.parse(
  await readFile(
    path.join(process.env.ARTIFACTS_DIR, "upgrade-baseline.json"),
    "utf8",
  ),
);
const endpoints = [
  ["relay", `ws://127.0.0.1:${ports.alice_port}`],
  ["asset-hub", `ws://127.0.0.1:${ports.para_1000_collator_port}`],
  ["people", `ws://127.0.0.1:${ports.para_1004_collator_port}`],
  ["bulletin", `ws://127.0.0.1:${ports.para_1010_collator_port}`],
];
const candidates = new Map([
  ["asset-hub", process.env.ASSET_HUB_WASM],
  ["people", process.env.PEOPLE_WASM],
]);
const authorizedUpgradeKey =
  "0x26aa394eea5630e07c48ae0c9558cef72fa9f1bf25567808771bff091dc89ecd";
const observationSeconds = Number(
  process.env.POST_UPGRADE_OBSERVATION_SECONDS ?? "900",
);
const observationIntervalSeconds = Number(
  process.env.POST_UPGRADE_OBSERVATION_INTERVAL_SECONDS ??
    String(Math.min(60, observationSeconds)),
);

if (!Number.isInteger(observationSeconds) || observationSeconds <= 0) {
  throw new Error(
    "POST_UPGRADE_OBSERVATION_SECONDS must be a positive integer",
  );
}
if (
  !Number.isInteger(observationIntervalSeconds) ||
  observationIntervalSeconds <= 0 ||
  observationIntervalSeconds > observationSeconds
) {
  throw new Error(
    "POST_UPGRADE_OBSERVATION_INTERVAL_SECONDS must be a positive integer no greater than POST_UPGRADE_OBSERVATION_SECONDS",
  );
}

await Promise.all(endpoints.map(([, endpoint]) => waitForRpc(endpoint, 300_000)));

for (const [name, endpoint] of endpoints) {
  const [runtimeVersion, codeHex] = await Promise.all([
    rpc(endpoint, "state_getRuntimeVersion"),
    rpc(endpoint, "state_getStorage", ["0x3a636f6465"]),
  ]);
  const code = Buffer.from(codeHex.slice(2), "hex");
  const candidatePath = candidates.get(name);
  if (candidatePath) {
    const candidate = await readFile(candidatePath);
    if (runtimeVersion.specVersion !== Number(process.env.CANDIDATE_SPEC_VERSION)) {
      throw new Error(
        `${name}: expected candidate spec ${process.env.CANDIDATE_SPEC_VERSION}, got ${runtimeVersion.specVersion}`,
      );
    }
    if (!code.equals(candidate)) throw new Error(`${name}: candidate :code mismatch`);
    const authorization = await rpc(endpoint, "state_getStorage", [authorizedUpgradeKey]);
    if (authorization !== null) {
      throw new Error(`${name}: AuthorizedUpgrade was not consumed`);
    }
    console.log(`${name}: candidate runtime ${runtimeVersion.specVersion} active`);
  } else {
    const digest = createHash("sha256").update(code).digest("hex");
    if (
      runtimeVersion.specVersion !== baseline[name].specVersion ||
      digest !== baseline[name].codeSha256
    ) {
      throw new Error(`${name}: runtime changed even though no upgrade was requested`);
    }
    console.log(`${name}: runtime unchanged at ${runtimeVersion.specVersion}`);
  }
}

const before = new Map();
for (const [name, endpoint] of endpoints) {
  const block = hexBlockNumber(await rpc(endpoint, "chain_getHeader"));
  before.set(name, block);
}

console.log(
  `Observing all four chains for ${observationSeconds} seconds after the upgrades...`,
);
const startedAt = Date.now();
const deadline = startedAt + observationSeconds * 1_000;
let previous = new Map(before);
while (Date.now() < deadline) {
  const waitMilliseconds = Math.min(
    observationIntervalSeconds * 1_000,
    deadline - Date.now(),
  );
  await new Promise((resolve) => setTimeout(resolve, waitMilliseconds));

  const elapsedSeconds = Math.round((Date.now() - startedAt) / 1_000);
  const current = new Map();
  for (const [name, endpoint] of endpoints) {
    const block = hexBlockNumber(await rpc(endpoint, "chain_getHeader"));
    if (block <= previous.get(name)) {
      throw new Error(
        `${name} stalled at block ${block} during the post-upgrade observation`,
      );
    }
    current.set(name, block);
  }
  console.log(
    `post-upgrade +${elapsedSeconds}s: ${endpoints
      .map(([name]) => `${name} ${previous.get(name)} -> ${current.get(name)}`)
      .join(", ")}`,
  );
  previous = current;
}

for (const [name] of endpoints) {
  console.log(`${name}: advanced ${before.get(name)} -> ${previous.get(name)}`);
}

console.log(
  `Only Asset Hub and People upgraded; all four chains continued producing blocks throughout the ${observationSeconds}-second post-upgrade observation.`,
);
