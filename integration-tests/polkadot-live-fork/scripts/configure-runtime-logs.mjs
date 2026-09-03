import { readFile, writeFile } from "node:fs/promises";

const configPath = process.argv[2];
const logFilter = process.env.COLLATOR_RUNTIME_LOG;
if (!configPath)
  throw new Error("usage: configure-runtime-logs.mjs <bite-config.toml>");
if (!logFilter) throw new Error("COLLATOR_RUNTIME_LOG is required");

const selected = new Set(["Collator-1000", "Collator-1004"]);
const configured = new Set();
let currentCollator;
const lines = (await readFile(configPath, "utf8")).split("\n");
const updated = lines.map((line) => {
  const name = line.match(/^name = "(Collator-[0-9]+)"$/)?.[1];
  if (name) currentCollator = name;

  const logArgument = line.match(/^(\s*)"-l=.*",$/);
  if (!logArgument || !selected.has(currentCollator)) return line;
  configured.add(currentCollator);
  return `${logArgument[1]}"-l=${logFilter}",`;
});

for (const collator of selected) {
  if (!configured.has(collator)) {
    throw new Error(`failed to configure runtime logs for ${collator}`);
  }
}

await writeFile(configPath, updated.join("\n"));
console.log(
  "Enabled runtime and Individuality logs on Asset Hub and People collators.",
);
