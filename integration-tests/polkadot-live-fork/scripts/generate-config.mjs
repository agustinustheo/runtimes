import { mkdir, stat, writeFile } from "node:fs/promises";
import path from "node:path";

for (const variable of ["ASSET_HUB_WASM", "PEOPLE_WASM", "BULLETIN_WASM", "BULLETIN_SPEC"]) {
  const value = process.env[variable];
  if (!value || !path.isAbsolute(value)) throw new Error(`${variable} must be an absolute path`);
  await stat(value);
}

await mkdir(process.env.GENERATED_DIR, { recursive: true });
await mkdir(process.env.ARTIFACTS_DIR, { recursive: true });

const config = `base_path = ${JSON.stringify(process.env.ARTIFACTS_DIR)}
and_spawn = false

[relaychain]
network = "polkadot"
sync_url = ${JSON.stringify(process.env.RELAY_RPC)}

[[parachains]]
type = "asset-hub"
rpc_endpoint = ${JSON.stringify(process.env.ASSET_HUB_RPC)}
runtime_override = ${JSON.stringify(process.env.ASSET_HUB_WASM)}

[[parachains]]
type = "people"
rpc_endpoint = ${JSON.stringify(process.env.PEOPLE_RPC)}
runtime_override = ${JSON.stringify(process.env.PEOPLE_WASM)}

[[parachains]]
type = "custom"
id = 1010
cores = 1
rpc_endpoint = ${JSON.stringify(process.env.BULLETIN_RPC)}
chain_spec = ${JSON.stringify(process.env.BULLETIN_SPEC)}
runtime_override = ${JSON.stringify(process.env.BULLETIN_WASM)}
`;

const destination = path.join(process.env.GENERATED_DIR, "polkadot.toml");
await writeFile(destination, config);
console.log(destination);
