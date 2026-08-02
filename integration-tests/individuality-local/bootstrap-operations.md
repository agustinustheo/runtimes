# Local bootstrap operation map

This map ports the order of `individuality/scripts/initial-setup` to the Polkadot local network.
It is intentionally explicit about calls which need the **local-only governance dispatcher**. The
dispatcher must accept only the three loopback endpoints configured by this harness and must never
be replaced with Sudo or a production origin.

| Order | Reference step | Local chain / adaptation | Required authority or observable result |
| --- | --- | --- | --- |
| 1 | `01a`, `01d` funding | Relay, People `1004`, Asset Hub `1000`; use local dev accounts and DOT's 10 decimals | Signed local dev transfer; fund the People sovereign before upward XCM. |
| 2 | `01b` HRMP | People `1004` then Asset Hub `1000` | Governance-dispatched parent XCM wrapping `Hrmp.establish_channel_with_system`; do not add a genesis HRMP stanza. |
| 3 | `03a`–`05c` backing assets and pools | Asset Hub then People foreign assets; choose local test IDs not production assumptions | Governance-dispatched `Assets.force_create`, metadata/rate calls, and local pool liquidity. |
| 4 | `06a`–`06c` PGAS and alias fee | Asset Hub, fixed PGAS ID `2_000_000_000` | `Pgas.create_pgas_asset` is expected to hit the unresolved `BadAssetId` migration issue. Do not pre-create it to hide that result. |
| 5 | `07` SRS chunks | People `1004` | Governance-dispatched `Utility.dispatch_as(Authorized, ChunksManager.add_chunks(...))` for the committed R2e9/R2e10 pages from the reference suite. |
| 6 | `08`, `09`, `11` collections and onboarding | People `1004` | Run the unsigned collection creation, then governance-dispatch the bounded local sizing/design-family calls needed by the test. |
| 7 | `10` ring-root subscription | People `1004` to Asset Hub `1000`, subscriber index `97` | Governance-dispatched `MembersNotifier.subscribe(1000, [(people, R2e9), (people-lite, R2e9)], 97)`; wait for offchain pagination and XCMP. |
| 8 | `12a`–`12c` attestation | People and Asset Hub | Governance-dispatched invite/allowance/proxy calls with local attestation accounts. |
| 9 | `13` DotNS | Asset Hub `1000` | Governance-dispatched `DotnsGateway.set_dispatcher_address` with a local test dispatcher address. |

Run `scripts/assertions.sh` only after step 7. It proves subscriber presence, `Active` status,
R2e9, and a delivered root. A proof-backed PGAS/alias transaction is deliberately a final check:
it cannot pass while the fixed-ID PGAS migration remains unresolved.
