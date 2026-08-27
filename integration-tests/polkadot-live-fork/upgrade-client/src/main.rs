// Copyright (C) Parity Technologies (UK) Ltd.
// SPDX-License-Identifier: Apache-2.0

use std::{path::PathBuf, time::Duration};

use anyhow::{bail, Context, Result};
use blake2::{digest::consts::U32, Blake2b, Digest};
use clap::Parser;
use subxt::{dynamic::Value, OnlineClient, PolkadotConfig};

type Blake2b256 = Blake2b<U32>;

#[derive(Parser)]
#[command(about = "Apply and verify an authorized runtime upgrade on a Zombie Bite fork")]
struct Args {
	#[arg(long)]
	rpc: String,
	#[arg(long)]
	asset_hub_rpc: Option<String>,
	#[arg(long)]
	wasm: PathBuf,
	#[arg(long)]
	expected_spec: u32,
	#[arg(long)]
	chain: Chain,
	#[arg(long, default_value_t = 1200)]
	timeout_seconds: u64,
	/// Continue post-upgrade checks when this exact candidate is already active.
	/// This is only for recovering a test run whose upgrade succeeded but whose
	/// subsequent harness assertion failed; normal runs remain strict.
	#[arg(long, default_value_t = false)]
	allow_already_active: bool,
}

#[derive(Clone, Copy, clap::ValueEnum)]
enum Chain {
	AssetHub,
	People,
}

async fn dynamic_raw(
	client: &OnlineClient<PolkadotConfig>,
	pallet: &str,
	item: &str,
	keys: Vec<Value<()>>,
) -> Result<Option<Vec<u8>>> {
	let address = subxt::dynamic::storage(pallet, item, keys);
	let key = client.storage().address_bytes(&address)?;
	Ok(client.storage().at_latest().await?.fetch_raw(key).await?)
}

async fn connect(rpc: &str) -> Result<OnlineClient<PolkadotConfig>> {
	OnlineClient::<PolkadotConfig>::from_url(rpc)
		.await
		.with_context(|| format!("connect to {rpc}"))
}

async fn verify_asset_hub(
	client: &OnlineClient<PolkadotConfig>,
	original_next_asset_id: &Option<Vec<u8>>,
) -> Result<bool> {
	let next_asset_id = dynamic_raw(client, "Assets", "NextAssetId", vec![]).await?;
	if &next_asset_id != original_next_asset_id {
		bail!(
			"Assets.NextAssetId changed across the PGAS creation migration: before={}, after={}",
			original_next_asset_id
				.as_ref()
				.map(hex::encode)
				.unwrap_or_else(|| "<none>".into()),
			next_asset_id.as_ref().map(hex::encode).unwrap_or_else(|| "<none>".into())
		);
	}

	let pgas = dynamic_raw(client, "Assets", "Asset", vec![Value::u128(2_000_000_000)]).await?;
	let cursor = dynamic_raw(client, "MultiBlockMigrations", "Cursor", vec![]).await?;
	let revive_v4_id = b"pallet-revive-mbm\x03\x04";
	let revive_v4 = dynamic_raw(
		client,
		"MultiBlockMigrations",
		"Historic",
		vec![Value::from_bytes(revive_v4_id)],
	)
	.await?;
	let subscription = dynamic_raw(client, "MembersSubscriber", "Subscription", vec![]).await?;
	let exponent = dynamic_raw(
		client,
		"MembersSubscriber",
		"RingCollectionExponents",
		vec![Value::from_bytes(b"pop:polkadot.network/people     ")],
	)
	.await?;
	if subscription.is_some() || exponent.is_some() {
		bail!("Asset Hub Individuality subscription existed before the People upgrade");
	}

	Ok(pgas.is_some() && cursor.is_none() && revive_v4.is_some())
}

fn verify_people_metadata(client: &OnlineClient<PolkadotConfig>) -> Result<()> {
	for pallet in [
		"RelayRandomness",
		"OriginRestriction",
		"People",
		"DummyDim",
		"PeopleLite",
		"Resources",
		"ChunksManager",
		"Members",
		"Coinage",
		"MembersNotifier",
		"Honour",
		"Parameters",
		"NetworkSuffix",
	] {
		if client.metadata().pallet_by_name(pallet).is_none() {
			bail!("People candidate metadata is missing {pallet}");
		}
	}
	Ok(())
}

async fn verify_individuality_xcm(
	people_rpc: &str,
	asset_hub_rpc: &str,
	timeout_seconds: u64,
) -> Result<()> {
	let deadline = tokio::time::Instant::now() + Duration::from_secs(timeout_seconds);
	let collection = b"pop:polkadot.network/people     ";
	loop {
		if tokio::time::Instant::now() >= deadline {
			bail!("timed out waiting for People-to-Asset-Hub subscription initialization XCM");
		}

		let people = connect(people_rpc).await?;
		let asset_hub = connect(asset_hub_rpc).await?;
		let subscriber =
			dynamic_raw(&people, "MembersNotifier", "Subscribers", vec![Value::u128(1000)]).await?;
		let pending =
			dynamic_raw(&people, "MembersNotifier", "PendingInit", vec![Value::u128(1000)]).await?;
		let subscription =
			dynamic_raw(&asset_hub, "MembersSubscriber", "Subscription", vec![]).await?;
		let exponent = dynamic_raw(
			&asset_hub,
			"MembersSubscriber",
			"RingCollectionExponents",
			vec![Value::from_bytes(collection)],
		)
		.await?;

		if subscriber.is_some() && pending.is_none() && subscription.is_some() && exponent.is_some()
		{
			println!(
				"People-to-Asset-Hub initialization XCM completed; Asset Hub subscription is active"
			);
			return Ok(());
		}

		println!(
			"waiting for Individuality XCM (subscriber={}, pending={}, subscription={}, exponent={})",
			subscriber.is_some(),
			pending.is_some(),
			subscription.is_some(),
			exponent.is_some()
		);
		tokio::time::sleep(Duration::from_secs(6)).await;
	}
}

#[tokio::main]
async fn main() -> Result<()> {
	let args = Args::parse();
	let code = tokio::fs::read(&args.wasm)
		.await
		.with_context(|| format!("read {}", args.wasm.display()))?;
	let client = connect(&args.rpc).await?;
	let original_spec = client.runtime_version().spec_version;
	let original_code = client
		.storage()
		.at_latest()
		.await?
		.fetch_raw(b":code".to_vec())
		.await?
		.context("live-fork state has no :code")?;

	if original_spec == args.expected_spec && original_code == code {
		if !args.allow_already_active {
			bail!(
				"fork already runs the candidate code at spec_version {original_spec}; pass --allow-already-active only to recover a run whose upgrade already succeeded"
			);
		}

		println!(
			"candidate code is already active at spec {original_spec}; continuing explicit recovery checks"
		);
		if matches!(args.chain, Chain::People) {
			verify_people_metadata(&client)?;
			println!("People candidate metadata contains the current Individuality pallet set");
			let asset_hub_rpc = args
				.asset_hub_rpc
				.as_deref()
				.context("--asset-hub-rpc is required for the People upgrade")?;
			verify_individuality_xcm(&args.rpc, asset_hub_rpc, args.timeout_seconds).await?;
		}
		return Ok(());
	}

	if original_spec >= args.expected_spec {
		bail!(
			"refusing upgrade: current spec_version {original_spec} is not below candidate {}",
			args.expected_spec
		);
	}

	if original_code == code {
		bail!("fork already runs the candidate code");
	}

	let mut expected_authorization = Blake2b256::digest(&code).to_vec();
	expected_authorization.push(1);
	let authorization = dynamic_raw(&client, "System", "AuthorizedUpgrade", vec![])
		.await?
		.context("System.AuthorizedUpgrade was not injected")?;
	if authorization != expected_authorization {
		bail!("System.AuthorizedUpgrade does not authorize the candidate code hash");
	}

	let original_next_asset_id = match args.chain {
		Chain::AssetHub => dynamic_raw(&client, "Assets", "NextAssetId", vec![]).await?,
		Chain::People => None,
	};

	println!(
		"submitting unsigned System.apply_authorized_upgrade: spec {original_spec} -> {}",
		args.expected_spec
	);
	let payload =
		subxt::dynamic::tx("System", "apply_authorized_upgrade", vec![Value::from_bytes(&code)]);
	let transaction = client.tx().create_unsigned(&payload)?;
	transaction.submit_and_watch().await?.wait_for_finalized_success().await?;
	println!("upgrade extrinsic finalized successfully");

	let deadline = tokio::time::Instant::now() + Duration::from_secs(args.timeout_seconds);
	loop {
		if tokio::time::Instant::now() >= deadline {
			bail!("timed out waiting for candidate code and migrations");
		}

		match connect(&args.rpc).await {
			Ok(post_client) => {
				let spec = post_client.runtime_version().spec_version;
				let stored_code =
					post_client.storage().at_latest().await?.fetch_raw(b":code".to_vec()).await?;
				if spec == args.expected_spec && stored_code.as_deref() == Some(code.as_slice()) {
					match args.chain {
						Chain::AssetHub => {
							if verify_asset_hub(&post_client, &original_next_asset_id).await? {
								println!(
                                    "Asset Hub upgraded to {spec}; PGAS exists, NextAssetId is preserved, Revive v4 is historic, and no Individuality subscription exists before People upgrades"
                                );
								break;
							}
							println!(
                                "Asset Hub code is active at spec {spec}; waiting for multi-block migrations"
                            );
						},
						Chain::People => {
							verify_people_metadata(&post_client)?;
							println!(
								"People upgraded to {spec}; the current Individuality pallet set is present in live metadata"
							);
							break;
						},
					}
				} else {
					println!("waiting for code enactment (current spec {spec})");
				}
			},
			Err(error) => println!("RPC temporarily unavailable during upgrade: {error:#}"),
		}

		tokio::time::sleep(Duration::from_secs(6)).await;
	}

	if matches!(args.chain, Chain::People) {
		let asset_hub_rpc = args
			.asset_hub_rpc
			.as_deref()
			.context("--asset-hub-rpc is required for the People upgrade")?;
		verify_individuality_xcm(&args.rpc, asset_hub_rpc, args.timeout_seconds).await?;
	}

	Ok(())
}
