import { rpc } from "./rpc.mjs";

const [endpoint, key] = process.argv.slice(2);
if (!endpoint || !key) {
  throw new Error("usage: node read-storage.mjs <endpoint> <storage-key>");
}

const value = await rpc(endpoint, "state_getStorage", [key], 30_000);
if (!value) throw new Error(`live storage key ${key} is absent at ${endpoint}`);
console.log(value.slice(2));
