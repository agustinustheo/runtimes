# Individuality local-network harness

Fork-only validation for Individuality on People Polkadot (1004) and Asset Hub
Polkadot (1000). It never changes a production runtime, adds sudo, or pre-opens
HRMP at genesis.

## Preconditions

- polkadot, polkadot-omni-node, zombienet, jq, and dot are on PATH.
- A clean WASM build can take 30--60 minutes. Cached binaries from the sibling
  Individuality checkout may be reused through PATH.
- LOCAL_GOVERNANCE_SUBMIT accepts a chain alias and encoded call, and submits only
  through the local network governance origin.

The adapter is intentionally external: production runtimes have no sudo.
Local-only genesis seeding plus governance-origin dispatch is the sole authority
mechanism. Never point the adapter at a public endpoint.

## Runbook

From this directory:

1. Run `bash scripts/build-wasm.sh`.
2. Run `bash scripts/generate-specs.sh`.
3. Spawn with `bash scripts/spawn.sh` (set `ZOMBIENET_DIR` first if the temporary default is not
   wanted).
4. Set `LOCAL_GOVERNANCE_SUBMIT` and run `bash scripts/bootstrap-plan.sh`.
5. After notifier offchain-worker pages arrive, run `bash scripts/assertions.sh`.

The generator is this repository chain-spec-generator. It creates raw local specs
for polkadot-local, people-polkadot-local (1004), asset-hub-polkadot-local
(1000), and bulletin-polkadot-local (1010). The relay genesis patch enables
EccRfc163. HRMP is opened only after parachains produce blocks, avoiding the
genesis DMQ-head mismatch.

Bootstrap order mirrors the reference suite: funding; bidirectional HRMP; backing
assets and pools; PGAS; ZK chunks; People collection; ring-root subscription;
attestation allowances; DotNs dispatcher. Assertions require an Active
MembersSubscriber subscription, R2e9, and a delivered ring root.

[bootstrap-operations.md](bootstrap-operations.md) is the human-runnable authority and adaptation
map for each reference step. In particular, it identifies the only allowed local authority route
for every formerly-Sudo call and distinguishes the expected PGAS failure from a successful
bootstrap.

The PGAS/alias proof flow is not marked passing: PGAS fixed-id creation at
2,000,000,000 still conflicts with Assets NextAssetId.

## Live migration rehearsal

Set `CHOPSTICKS_BIN` to the Chopsticks executable to test (the sibling e2e cache is used when it
is present; it is currently 1.3.1 and reproduces the documented host-function limitation), build
WASM, then run:

    bash scripts/run-chopsticks.sh asset-hub
    bash scripts/run-chopsticks.sh people

This forks the configured live endpoint, overrides runtime only inside
Chopsticks, and runs pre/post migration checks. See chopsticks/expected-results.md.
Never submit its runtime upgrade or migration to a public chain.

The candidate has the same `spec_version` as the live state, so the wrapper deliberately passes
`--disable-spec-check`; it does not suppress any pre/post migration checks. The 2026-08-02 live
attempt is recorded in `chopsticks/asset-hub-run-2026-08-02.md`: both Chopsticks 1.3.1 and 1.5.0
stop before `on_runtime_upgrade` because they lack
`ext_host_calls_bls12_381_final_exponentiation_version_1`. Use the repository-compatible
`try-runtime v0.10.1` snapshot workflow below until Chopsticks supplies that host function.
