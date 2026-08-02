# Current expected migration result

Run the Asset Hub rehearsal before changing migrations. The expected outcome is
not successful PGAS creation:

1. CreatePgasAsset attempts asset 2_000_000_000.
2. pallet-assets accepts creation at Assets NextAssetId, so the fixed id is
   rejected with BadAssetId.
3. The upstream migration logs the create error and returns success, so a
   migration success line is not evidence that the asset exists.

Capture the full try-runtime log in chopsticks/output. Do not mask this finding by
pre-creating the asset in forked state.

If Chopsticks stops at `ext_host_calls_bls12_381_final_exponentiation_version_1`, it has not
executed `on_runtime_upgrade` and therefore has not demonstrated the PGAS result. This occurred
with 1.3.1 and 1.5.0 on 2026-08-02; see asset-hub-run-2026-08-02.md and use the documented
`try-runtime` snapshot alternative until the host call is supported.
