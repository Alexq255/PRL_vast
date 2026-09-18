#!/usr/bin/env bash
# Pearl (PRL) on Kryptex Pool — Vast.ai launcher for one RTX 4070 Super.
# Run: bash start_prl_kryptex_rtx4070s.sh
# Stop: Ctrl+C. No clocks, power limits, or fan settings are changed.

set -Eeuo pipefail

KRYPTEX_ACCOUNT="${KRYPTEX_ACCOUNT:-krxXKZVJJ6}"
WORKER_NAME="${WORKER_NAME:-vast-rtx4070s-$(date +%m%d-%H%M)}"
POOL="${POOL:-prl.kryptex.network:8048}"
BASE_DIR="${BASE_DIR:-$HOME/prl-srbminer}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }; }
need curl
need python3
need tar
need sha256sum
need md5sum
need nvidia-smi
need grep

gpu_names="$(nvidia-smi --query-gpu=name --format=csv,noheader)"
if ! grep -qi 'RTX 4070 SUPER' <<<"$gpu_names"; then
  echo "This script is intentionally limited to RTX 4070 Super." >&2
  echo "Detected GPU(s): $gpu_names" >&2
  exit 1
fi

echo "== GPU =="
nvidia-smi --query-gpu=name,driver_version,memory.total,power.limit --format=csv,noheader

mkdir -p "$BASE_DIR/releases" "$BASE_DIR/logs"
cd "$BASE_DIR"

echo "== Resolving official SRBMiner-MULTI release =="
release_json="$(curl --fail --location --silent --show-error --retry 3 \
  https://api.github.com/repos/doktor83/SRBMiner-Multi/releases/latest)"

readarray -t release_info < <(printf '%s' "$release_json" | python3 -c '
import json, re, sys
r = json.load(sys.stdin)
assets = r.get("assets", [])
matches = [a for a in assets if re.fullmatch(r"SRBMiner-Multi-.*-Linux\\.tar\\.gz", a.get("name", ""), re.I)]
if not matches:
    raise SystemExit("No Linux tar.gz asset was found in the latest SRBMiner-MULTI release.")
a = matches[0]
body = r.get("body") or ""
md5 = re.search(r"\\b([a-fA-F0-9]{32})\\s+\\*" + re.escape(a["name"]), body)
print(r.get("tag_name", "unknown"))
print(a["browser_download_url"])
print(a.get("digest") or "")
print(md5.group(1).lower() if md5 else "")
')

release_tag="${release_info[0]}"
asset_url="${release_info[1]}"
asset_digest="${release_info[2]:-}"
expected_md5="${release_info[3]:-}"
archive="$BASE_DIR/releases/srbminer-${release_tag}-linux.tar.gz"
extract_dir="$BASE_DIR/releases/srbminer-${release_tag}"

if [[ ! -f "$archive" ]]; then
  curl --fail --location --show-error --retry 3 --output "$archive.part" "$asset_url"
  mv "$archive.part" "$archive"
fi

if [[ "$asset_digest" == sha256:* ]]; then
  [[ "$(sha256sum "$archive" | awk '{print $1}')" == "${asset_digest#sha256:}" ]] || {
    echo "SHA-256 verification failed; refusing to run." >&2; exit 1;
  }
  echo "Release ${release_tag}: SHA-256 verified."
elif [[ -n "$expected_md5" ]]; then
  [[ "$(md5sum "$archive" | awk '{print $1}')" == "$expected_md5" ]] || {
    echo "MD5 verification failed; refusing to run." >&2; exit 1;
  }
  echo "Release ${release_tag}: release MD5 verified."
else
  echo "Warning: no published checksum was detected; downloaded only from the official SRBMiner release."
fi

if [[ ! -x "$extract_dir/SRBMiner-MULTI" ]]; then
  rm -rf "$extract_dir"
  mkdir -p "$extract_dir"
  tar -xzf "$archive" -C "$extract_dir"
  miner_path="$(find "$extract_dir" -type f -name SRBMiner-MULTI -print -quit)"
  [[ -n "$miner_path" ]] || { echo "SRBMiner-MULTI was not present in the archive." >&2; exit 1; }
  chmod +x "$miner_path"
  if [[ "$miner_path" != "$extract_dir/SRBMiner-MULTI" ]]; then
    mv "$miner_path" "$extract_dir/SRBMiner-MULTI"
  fi
fi

MINER="$extract_dir/SRBMiner-MULTI"
log_file="$BASE_DIR/logs/prl-$(date +%Y%m%d-%H%M%S).log"

echo "== Starting PRL mining =="
echo "Pool:    $POOL"
echo "Account: $KRYPTEX_ACCOUNT"
echo "Worker:  $WORKER_NAME"
echo "Log:     $log_file"

"$MINER" \
  --disable-cpu \
  --algorithm pearlhash \
  --pool "$POOL" \
  --wallet "$KRYPTEX_ACCOUNT" \
  --worker "$WORKER_NAME" \
  --tls true \
  2>&1 | tee -a "$log_file"
