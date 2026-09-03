import { rpc, hexBlockNumber } from "./rpc.mjs";

const endpoints = [
  ["relay", process.env.RELAY_RPC, "Polkadot"],
  ["asset-hub", process.env.ASSET_HUB_RPC, "Polkadot Asset Hub"],
  ["people", process.env.PEOPLE_RPC, "Polkadot People"],
  ["bulletin", process.env.BULLETIN_RPC, "Polkadot Bulletin"],
];

for (const [name, endpoint, expectedChain] of endpoints) {
  const [chain, header, genesis, runtimeVersion] = await Promise.all([
    rpc(endpoint, "system_chain"),
    rpc(endpoint, "chain_getHeader"),
    rpc(endpoint, "chain_getBlockHash", [0]),
    rpc(endpoint, "state_getRuntimeVersion"),
  ]);
  if (chain !== expectedChain) throw new Error(`${name}: expected ${expectedChain}, got ${chain}`);
  if (name === "bulletin" && genesis !== process.env.BULLETIN_GENESIS_HASH) {
    throw new Error(`Bulletin spec/RPC genesis mismatch: ${genesis}`);
  }
  const expectedSpecVersion = {
    "asset-hub": Number(process.env.ASSET_HUB_LIVE_SPEC_VERSION),
    people: Number(process.env.PEOPLE_LIVE_SPEC_VERSION),
  }[name];
  if (expectedSpecVersion && runtimeVersion.specVersion !== expectedSpecVersion) {
    throw new Error(
      `${name}: expected live spec_version ${expectedSpecVersion}, got ${runtimeVersion.specVersion}`,
    );
  }
  console.log(
    `${name}: ${chain}, block ${hexBlockNumber(header)}, spec ${runtimeVersion.specVersion}, genesis ${genesis}`,
  );
}
