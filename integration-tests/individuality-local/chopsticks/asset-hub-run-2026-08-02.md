# Asset Hub live-state rehearsal — 2026-08-02

This is an attempted PGAS migration rehearsal against
`wss://polkadot-asset-hub-rpc.polkadot.io`, with the freshly built Asset Hub Polkadot
`try-runtime` WASM and pre/post checks. It made no write to a public chain.

Both the cached Chopsticks 1.3.1 and an isolated Chopsticks 1.5.0 stopped before
`on_runtime_upgrade` with the same host-function error:

```text
Current runtime spec_name: statemint, spec_version: 2003002
New runtime spec_name: statemint, spec_version: 2003002
Error: Unresolved function `env`:`ext_host_calls_bls12_381_final_exponentiation_version_1`
```

The initial run also correctly required `--disable-spec-check`, because the candidate has the same
spec version as the live runtime. Disabling that *version* gate still leaves Chopsticks unable to
execute the runtime, so this is not evidence that the PGAS migration passed or failed.

The expected PGAS result remains `BadAssetId`: the migration tries to create fixed asset
`2_000_000_000` while live Asset Hub enforces the current `NextAssetId`; it logs that failure and
returns success. Re-run this file's command after Chopsticks adds the BLS host call, or use the
repository-compatible `try-runtime v0.10.1` snapshot workflow documented in the parent README.
