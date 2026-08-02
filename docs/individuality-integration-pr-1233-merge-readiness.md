# Merge-readiness: Individuality integration PR #1233

Reviewed 2026-08-02 against `polkadot-fellows/runtimes` PR #1233, head
`56221a433` (`individuality-integration`) and the reference checkout at
`/Users/theo/Projects/parity/individuality` (`903d3437`).

## Verdict

**Do not merge.** The runtime build configurations compile, but the upgrade cannot create the
fixed PGAS asset on live Asset Hub Polkadot, which leaves every PGAS flow unusable. The PR CI is
also red because the private Individuality dependency cannot be fetched in GitHub Actions. There
is no end-to-end test of the People-to-Asset-Hub ring-root delivery path.

## What passed

All commands below used `CARGO_NET_GIT_FETCH_WITH_CLI=true`. This is necessary locally because
Cargo's libgit2 SSH transport cannot authenticate to `paritytech/individuality`, while the local
Git SSH transport can.

| Check | Result |
| --- | --- |
| `cargo build --release -p people-polkadot-runtime -p asset-hub-polkadot-runtime` | Passed (6m 22s), no compiler warnings. |
| Same build with `--features runtime-benchmarks` | Passed (3m 53s), no compiler warnings. |
| Same build with `--features try-runtime` | Passed (2m 48s), no compiler warnings. |
| `cargo test -p people-polkadot-integration-tests -p asset-hub-polkadot-integration-tests` | Passed: 78 Asset Hub tests and 20 People tests. The test run logs expected emulator warnings/errors for negative-path XCM cases. |
| `cargo test -p zombienet-sdk-tests --no-run` | Passed. It emits Cargo's future-incompatibility warning for third-party `trie-db v0.30.0`. |

The existing PR is open and draft. Its `rustfmt` and changelog checks pass, but `clippy` and
workspace-features are failing. Both jobs fail while fetching
`ssh://git@github.com/paritytech/individuality@fba8a64…`: the Actions runner has no SSH
credential, so Cargo reports the revision as unavailable. This is an actionable CI/reproducibility
blocker even though the local Git-CLI transport can fetch that revision.

## Findings, highest severity first

### P0 — PGAS is not created on live Asset Hub

`CreatePgasAsset` is in `Unreleased`, but Asset Hub's trust-backed assets use `NextAssetId`.
Creating asset `2_000_000_000` therefore returns `BadAssetId`; the migration only logs the error
and reports success. The runtime upgrade can complete with no PGAS asset, making claims, PGAS
payment, and PGAS-denominated Revive deposits dead on arrival.

- [migrations.rs](../system-parachains/asset-hubs/asset-hub-polkadot/src/migrations.rs:170)
  documents the failure and still schedules the migration at line 198.
- [individuality.rs](../system-parachains/asset-hubs/asset-hub-polkadot/src/individuality.rs:103)
  fixes the incompatible asset id at line 111.
- The upstream migration confirms that it merely logs an error; its try-runtime post-check requires
  the asset to exist: `/Users/theo/Projects/parity/individuality/pallets/pgas/src/migration.rs:34`.

Resolve the Asset Hub asset-ID strategy before enabling the migration, then run the migration
against a current Asset Hub snapshot. Do not rely on the migration's log line as a success signal.

### P0 — PR CI cannot resolve the private Individuality source dependency

Every Individuality workspace dependency uses an SSH URL in
[Cargo.toml](../Cargo.toml:92). GitHub Actions has no corresponding credential, causing both
required checks to fail before metadata or linting runs. Either provide CI read access safely or
move the dependency source to a CI-resolvable, pinned location.

### P1 — the critical People → Asset Hub ring-root flow has no in-repo test

The emulated suites contain no `MembersNotifier`, `MembersSubscriber`, `Pgas`, or Individuality
reference. The passing 98 tests consequently do not exercise the new wire protocol:

1. configure a People collection/ring and root;
2. open both HRMP directions;
3. root-call `MembersNotifier::subscribe(1000, collections, 97)`;
4. drive XCMP delivery; and
5. assert Asset Hub `MembersSubscriber::Subscription == Active`, the propagated ring exponent/root,
   and acceptance of a proof made against that root.

The wiring itself is internally consistent: the target uses People `1004`, Asset Hub `1000`,
Bulletin `1010`, notifier pallet index `69`, subscriber index `97`, `Pgas` index `99`, and
`PgasAllowance` index `252`. The Bulletin endpoint uses
`polkadot_runtime_constants::system_parachain::BULLETIN_ID`, not a stale literal.

### P1 — long-term storage allocation is silently ineffective

Bulletin Polkadot does not yet contain `pallet-transaction-storage`. People nevertheless records
the allocation after sending XCM; the receiver discards the message, and there is no replay plan.
The provisional remote pallet index is also a guess.

- [individuality.rs](../system-parachains/people/people-polkadot/src/individuality.rs:919)

Disable or explicitly gate the allocation path until Bulletin deploys the receiving pallet and the
reconciliation procedure is designed.

### P1 — weights are placeholders, not Polkadot measurements

All newly added Individuality weight files state that they were generated against the Paseo
reference runtime. In addition, People uses generic upstream weights for `pallet-verify-signature`.

- [people weights](../system-parachains/people/people-polkadot/src/weights/mod.rs:1) (15 generated
  files; each has the placeholder notice at line 19)
- [Asset Hub weights](../system-parachains/asset-hubs/asset-hub-polkadot/src/weights/mod.rs:1)
  (6 generated files; same notice)
- [People verify-signature config](../system-parachains/people/people-polkadot/src/lib.rs:724)

Regenerate on the reference-hardware benchmark runner following
[weight-generation.md](../weight-generation.md:1) before release.

### P2 — current functionality requires an explicit bootstrap plan

The port intentionally omits development-only `storage-initialization`, `mob-rule`, and
`proof-of-ink`; this is documented and is not a divergence. But the deployed pallets remain inert
until the SRS, subscriptions, assets, pools, and origins are initialized. The PR correctly describes
the required deployment ordering in
[People individuality configuration](../system-parachains/people/people-polkadot/src/individuality.rs:76),
but it has not been exercised for the production runtime configuration.

## Open economics and allowance decisions

These values need team sign-off; this report proposes no values.

- `PlayDepositDefault = 2 * UNITS`: that is 2 DOT rather than the reference's 2 PAS.
  [individuality.rs](../system-parachains/people/people-polkadot/src/individuality.rs:440)
- Statement, notification, and long-term-storage allowances retain reference hard-coded values.
  [individuality.rs](../system-parachains/people/people-polkadot/src/individuality.rs:581)
- Coin denomination range, free unload allocation, backing-asset choice, and the HOLLAR-decimal
  invariant have not been selected for Polkadot.
  [individuality.rs](../system-parachains/people/people-polkadot/src/individuality.rs:712)
- Identity/alias and lite-person anonymous-origin allowances remain placeholders for
  `paritytech/individuality#1124`.
  [individuality.rs](../system-parachains/people/people-polkadot/src/individuality.rs:821)
- PGAS claim amount and per-period claim caps are unpriced Polkadot state/block-space subsidies.
  [individuality.rs](../system-parachains/asset-hubs/asset-hub-polkadot/src/individuality.rs:191)
- DotNS person-registration allowance/recovery needs an economics review alongside PGAS and alias
  policy. [individuality.rs](../system-parachains/asset-hubs/asset-hub-polkadot/src/individuality.rs:325)

## TODO checklist in changed runtime files

- [ ] Audit all hard-coded People values: currency, time, and stablecoin semantics
  ([individuality.rs](../system-parachains/people/people-polkadot/src/individuality.rs:23)).
- [ ] Confirm the 2-DOT game deposit
  ([individuality.rs](../system-parachains/people/people-polkadot/src/individuality.rs:443)).
- [ ] Move the local `MembershipProof` when `individuality#1125` permits it
  ([individuality.rs](../system-parachains/people/people-polkadot/src/individuality.rs:669)).
- [ ] Decide coinage economics and backing asset
  ([individuality.rs](../system-parachains/people/people-polkadot/src/individuality.rs:729)).
- [ ] Decide anonymous-origin allowances (`individuality#1124`)
  ([individuality.rs](../system-parachains/people/people-polkadot/src/individuality.rs:825)).
- [ ] Fix/gate Bulletin long-term storage and make the remote index non-provisional
  ([individuality.rs](../system-parachains/people/people-polkadot/src/individuality.rs:922)).
- [ ] Generate People-local `pallet-verify-signature` weights
  ([lib.rs](../system-parachains/people/people-polkadot/src/lib.rs:727)).
- [ ] Audit all hard-coded Asset Hub values and select PGAS claim economics
  ([individuality.rs](../system-parachains/asset-hubs/asset-hub-polkadot/src/individuality.rs:23),
  [individuality.rs](../system-parachains/asset-hubs/asset-hub-polkadot/src/individuality.rs:200)).
- [ ] Replace the incompatible PGAS asset creation migration
  ([migrations.rs](../system-parachains/asset-hubs/asset-hub-polkadot/src/migrations.rs:173)).
- [ ] Regenerate every added Individuality weight file (15 People and 6 Asset Hub files, all marked
  TODO at line 19).

## Zombienet/chopsticks port runbook

The existing runtimes zombienet smoke is not suitable as-is: it launches Coretime `1005` and
Bulletin `1010`, not People `1004` and Asset Hub `1000`. The Individuality harness is the correct
starting point, but its network is Paseo `1502`/`1500` and assumes Sudo.

1. On a separate `individuality-integration-local-testing` branch, add a dedicated network config
   using `polkadot-local`, `people-polkadot-local` (1004), `asset-hub-polkadot-local` (1000), and
   optionally `bulletin-polkadot-local` (1010). Generate all specs through this repository's
   `chain-spec-generator`; use raw specs for zombienet.
2. Carry the reference relay genesis `EccRfc163` host-function patch. It is needed when the People
   runtime validates ZK chunk payloads.
3. Do **not** preopen HRMP in genesis. Open both People ↔ Asset Hub channels after startup; the
   reference harness documents the genesis DMQ-head failure this avoids.
4. Replace every `Sudo.sudo` / `sudo_as` bootstrap operation. Production People and Asset Hub do
   not include Sudo. Choose and document one test-only authority mechanism before implementation:
   a local-only runtime/spec path with an explicit privileged bootstrap origin, or precisely seeded
   genesis state plus governance-origin dispatch. Do not silently change production origins.
5. Adapt accounts, endowed balances, token units, and all para IDs. Port the initialization steps in
   order: funding; HRMP; HOLLAR/XTRNL and pools; PGAS asset/pool/alias fee; SRS chunks; people
   collection; ring-root subscription; attestation allowance; DotNS dispatcher. The PGAS migration
   blocker must be fixed first, or use an explicitly validated test-only genesis setup.
6. Run the adapted initialization suite. Its required observable checks are People subscriber
   presence, Asset Hub `Subscription == Active`, propagated people exponent `R2e9`, and an actual
   proof-backed PGAS/alias flow. Add the same core assertion to an emulated test where possible.
7. For a live-state migration check, obtain the repository's v0.10.1 `try-runtime` binary, build
   the Asset Hub wasm with `try-runtime`, create/obtain a fresh Asset Hub snapshot, then run the
   workflow-equivalent `try-runtime --runtime <wasm> on-runtime-upgrade --checks=<CI checks> snap
   --path snapshot.raw`. The local machine had no `try-runtime` binary, so this was not executed.

## Release housekeeping

- The PR already has a substantive `[Unreleased]` CHANGELOG entry; no entry is missing.
- One WIP commit (`56221a433`) is not reviewable history. Squash/split into semantic, reviewed
  commits before final review.
- Run the generated-weight work on the designated reference-hardware runner and replace all
  placeholder files.
- Make CI capable of fetching the pinned Individuality revision, then run clippy, feature checks,
  migration checks, and the new ring-root test.

## Local-testing branch and signing state

The report is published in the fork-only stacked draft PR
<https://github.com/agustinustheo/runtimes/pull/1>, with base
`individuality-integration` and head `individuality-integration-local-testing`.
It does not target `polkadot-fellows/runtimes`.

The report commit is GPG-signed by the approved hardware key `C4F626D78900737B` with identity
`agustinus@parity.io`; `git log --show-signature` validates it. The gmail key was not used.
No harness files were added because the P0 migration and CI-source blockers stop the porting
stage.
