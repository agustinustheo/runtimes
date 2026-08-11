#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

mkdir -p "$TOOL_CACHE" "$TOOL_CACHE/bin" "$DG_DIR" "$GENERATED_DIR"

if [[ ! -d "$ZOMBIE_BITE_DIR/.git" ]]; then
  git clone "$ZOMBIE_BITE_REPOSITORY" "$ZOMBIE_BITE_DIR"
fi

if [[ "$(git -C "$ZOMBIE_BITE_DIR" rev-parse HEAD)" != "$ZOMBIE_BITE_COMMIT" ]]; then
  if ! git -C "$ZOMBIE_BITE_DIR" diff --quiet; then
    echo "Zombie Bite cache has local changes at the wrong revision: $ZOMBIE_BITE_DIR" >&2
    exit 1
  fi
  git -C "$ZOMBIE_BITE_DIR" fetch origin "$ZOMBIE_BITE_COMMIT"
  git -C "$ZOMBIE_BITE_DIR" checkout --detach "$ZOMBIE_BITE_COMMIT"
fi

if git -C "$ZOMBIE_BITE_DIR" diff --quiet; then
  git -C "$ZOMBIE_BITE_DIR" apply "$HARNESS_DIR/patches/zombie-bite-live-fork.patch"
elif ! git -C "$ZOMBIE_BITE_DIR" apply --reverse --check "$HARNESS_DIR/patches/zombie-bite-live-fork.patch"; then
  echo "Zombie Bite cache contains changes other than the pinned harness patch" >&2
  exit 1
fi

patch_sha="$(shasum -a 256 "$HARNESS_DIR/patches/zombie-bite-live-fork.patch" | awk '{print $1}')"
binary_version="$ZOMBIE_BITE_COMMIT:$patch_sha"
version_file="$TOOL_CACHE/bin/zombie-bite.version"
if [[ ! -x "$ZOMBIE_BITE_BIN" ]] || [[ ! -f "$version_file" ]] || [[ "$(<"$version_file")" != "$binary_version" ]]; then
  cargo build --release --locked --manifest-path "$ZOMBIE_BITE_DIR/Cargo.toml"
  install -m 755 "$ZOMBIE_BITE_DIR/target/release/zombie-bite" "$ZOMBIE_BITE_BIN"
  printf '%s\n' "$binary_version" > "$version_file"
fi

case "$(uname -s)-$(uname -m)" in
  Darwin-arm64) asset_suffix=-macos-arm64 ;;
  Linux-x86_64) asset_suffix= ;;
  *) echo "Unsupported host: $(uname -s) $(uname -m)" >&2; exit 1 ;;
esac

download_dg() {
  local name="$1"
  local expected="$2"
  local asset="${name}${asset_suffix}"
  local destination="$DG_DIR/$name"
  if [[ -f "$destination" ]] && [[ "$(shasum -a 256 "$destination" | awk '{print $1}')" == "$expected" ]]; then
    return
  fi
  curl -fL "https://github.com/paritytech/doppelganger-wrapper/releases/download/$DOPPELGANGER_VERSION/$asset" -o "$destination.download"
  if [[ "$(shasum -a 256 "$destination.download" | awk '{print $1}')" != "$expected" ]]; then
    echo "Checksum mismatch for $asset" >&2
    exit 1
  fi
  mv "$destination.download" "$destination"
  chmod +x "$destination"
}

if [[ "$asset_suffix" == "-macos-arm64" ]]; then
  download_dg doppelganger 662b5a05a2d348194ca12590114d7bdab370eab7b2294fe77d24aea7e1827909
  download_dg doppelganger-parachain 050ad81465e13827ce80d5bf230d3aa57cf332afbc8262dedb7c2aaf9309b7ec
  download_dg polkadot-execute-worker e35c08fc5c0db2bb1aa71505abfd99b41c74eefe7ffbece9095e34700ad92f84
  download_dg polkadot-prepare-worker 5edfe561560ca4926356a1164118c3939965143a20c5d94588f9af898a6c7757
else
  download_dg doppelganger 07b5b1c4501d6e8803f48402ecfe82c2c82ca621c92fd888b4a9d77f8ce5f072
  download_dg doppelganger-parachain 4660ca31e2256a2b958c6325602e5ec28d1d72fc75123861007350462d615e3f
  download_dg polkadot-execute-worker d24346bc93db44a032291f6e95dd422249190dccbff997a1648fae372ab44213
  download_dg polkadot-prepare-worker 873edc3cfb0c76a81fc76c3e2c0c8fd549e7cfcd5bd514b70da18f33e5d3b8f3
fi

ln -sfn doppelganger "$DG_DIR/polkadot"
if [[ ! -x "$PARACHAIN_NODE_BIN" ]]; then
  echo "Missing current SDK parachain node: $PARACHAIN_NODE_BIN" >&2
  echo "Build preview-net-v1/bin/polkadot-omni-node or set PARACHAIN_NODE_BIN." >&2
  exit 1
fi
ln -sfn "$PARACHAIN_NODE_BIN" "$DG_DIR/polkadot-parachain"

bulletin_url="https://raw.githubusercontent.com/paritytech/polkadot-bulletin-chain/$BULLETIN_SPEC_COMMIT/chainspecs/polkadot-chainspec.json"
if [[ ! -f "$BULLETIN_SPEC" ]] || [[ "$(shasum -a 256 "$BULLETIN_SPEC" | awk '{print $1}')" != "$BULLETIN_SPEC_SHA256" ]]; then
  curl -fL "$bulletin_url" -o "$BULLETIN_SPEC.download"
  if [[ "$(shasum -a 256 "$BULLETIN_SPEC.download" | awk '{print $1}')" != "$BULLETIN_SPEC_SHA256" ]]; then
    echo "Checksum mismatch for Bulletin chain spec" >&2
    exit 1
  fi
  mv "$BULLETIN_SPEC.download" "$BULLETIN_SPEC"
fi

echo "Zombie Bite and Doppelganger are ready in $TOOL_CACHE"
