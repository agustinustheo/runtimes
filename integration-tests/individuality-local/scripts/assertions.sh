#!/usr/bin/env bash
set -eo pipefail
command -v dot >/dev/null
[ -n "$PEOPLE_RPC" ] || PEOPLE_RPC=ws://127.0.0.1:12010
[ -n "$ASSET_HUB_RPC" ] || ASSET_HUB_RPC=ws://127.0.0.1:12020
PEOPLE_IDENTIFIER="0x706f703a706f6c6b61646f742e6e6574776f726b2f70656f706c652020202020"
dot chain add people --rpc "$PEOPLE_RPC" 2>/dev/null || true
dot chain add asset-hub --rpc "$ASSET_HUB_RPC" 2>/dev/null || true
subscriber="$(dot people.query.MembersNotifier.Subscribers 1000)"
subscription="$(dot asset-hub.query.MembersSubscriber.Subscription)"
exponent="$(dot asset-hub.query.MembersSubscriber.RingCollectionExponents "$PEOPLE_IDENTIFIER")"
roots="$(dot asset-hub.query.MembersSubscriber.RingRoots "$PEOPLE_IDENTIFIER" 0)"
printf '%s\n' "$subscriber" "$subscription" "$exponent" "$roots"
grep -qv '^undefined$' <<<"$subscriber"
grep -q 'Active' <<<"$subscription"
grep -q 'R2e9' <<<"$exponent"
grep -qv '^undefined$' <<<"$roots"
echo "People->Asset Hub ring-root subscription is active with a delivered root."
