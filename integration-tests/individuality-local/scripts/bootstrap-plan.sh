#!/usr/bin/env bash
set -eo pipefail

# The adapter must reject public endpoints; this script never emulates sudo.
[ -n "$LOCAL_GOVERNANCE_SUBMIT" ] || { echo "set LOCAL_GOVERNANCE_SUBMIT" >&2; exit 1; }
command -v dot >/dev/null
[ -n "$PEOPLE_RPC" ] || PEOPLE_RPC=ws://127.0.0.1:12010
[ -n "$ASSET_HUB_RPC" ] || ASSET_HUB_RPC=ws://127.0.0.1:12020
[ -n "$RELAY_RPC" ] || RELAY_RPC=ws://127.0.0.1:12000
dot chain add relay --rpc "$RELAY_RPC" 2>/dev/null || true
dot chain add people --rpc "$PEOPLE_RPC" 2>/dev/null || true
dot chain add asset-hub --rpc "$ASSET_HUB_RPC" 2>/dev/null || true

submit() {
	local chain="$1"
	local call="$2"
	"$LOCAL_GOVERNANCE_SUBMIT" "$chain" "$call"
}

echo "1/9 fund local relay, People, and Asset Hub operator accounts"
echo "2/9 open People(1004)->Asset Hub(1000), then Asset Hub->People HRMP"
echo "3/9 create/fund backing assets and pools through local governance"
echo "4/9 attempt PGAS setup at 2000000000 (currently expected BadAssetId)"
echo "5/9 upload committed ZK chunk hashes and pages"
echo "6/9 initialize People and People-lite collections"
echo "7/9 submit MembersNotifier.subscribe(1000, collections, 97)"
echo "8/9 set attestation allowances and DotNs dispatcher"
echo "9/9 run assertions after notifier pages are delivered"

collections='[["0x706f703a706f6c6b61646f742e6e6574776f726b2f70656f706c652020202020",{"type":"R2e9"}],["0x706f703a706f6c6b61646f742e6e6574776f726b2f70656f706c652d6c697465",{"type":"R2e9"}]]'
subscribe_call="$(dot --encode people.tx.MembersNotifier.subscribe 1000 "$collections" 97)"
submit people "$subscribe_call"
echo "Subscription submitted; complete preceding actions before asserting success."
