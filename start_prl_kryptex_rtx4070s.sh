#!/usr/bin/env bash
# PeakMiner PRL launcher for the NVIDIA GPUs visible in this Vast.ai instance.
set -Eeuo pipefail
KRYPTEX_ACCOUNT="${KRYPTEX_ACCOUNT:-krxXKZVJJ6}"
WORKER_NAME="${WORKER_NAME:-vast4070s01}"
POOL="${POOL:-prl.kryptex.network:8048}"
BASE_DIR="${BASE_DIR:-$HOME/prl-peakminer}"
VERSION=2.16.3
SHA256=a697538aec3cae7100204d168e5a2ca147da7b322b284a14c66b3484c8df99f4
URL="https://github.com/peakminer/peakminer/releases/download/v$VERSION/peakminer-$VERSION-linux-x86_64"
for tool in curl sha256sum nvidia-smi tee mktemp; do
  command -v "$tool" >/dev/null || { echo "Missing command: $tool" >&2; exit 1; }
done
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || { echo 'Requires Linux x86_64.' >&2; exit 1; }
echo '== GPU =='
nvidia-smi --query-gpu=name,driver_version,memory.total,power.limit --format=csv,noheader
mkdir -p "$BASE_DIR/bin" "$BASE_DIR/logs"
BASE_DIR="$(cd "$BASE_DIR" && pwd)"
MINER="$BASE_DIR/bin/peakminer-$VERSION"
download_tmp=''
trap 'if [[ -n "$download_tmp" ]]; then rm -f -- "$download_tmp"; fi' EXIT
verify() { printf '%s  %s\n' "$SHA256" "$1" | sha256sum --check --status; }
if [[ ! -f "$MINER" ]] || ! verify "$MINER"; then
  download_tmp="$(mktemp "$BASE_DIR/bin/download.XXXXXX")"
  curl --fail --location --proto '=https' --proto-redir '=https' --retry 3 --connect-timeout 30 --output "$download_tmp" "$URL"
  verify "$download_tmp" || { echo 'SHA-256 mismatch. Download will not be executed.' >&2; exit 1; }
  chmod 755 "$download_tmp"
  mv -- "$download_tmp" "$MINER"
  download_tmp=''
fi
chmod u+x "$MINER"
log_file="$BASE_DIR/logs/prl-$(date +%Y%m%d-%H%M%S)-$$.log"
printf 'PeakMiner %s: SHA-256 verified.\nPool: %s\nAccount: %s\nWorker: %s\nLog: %s\n' "$VERSION" "$POOL" "$KRYPTEX_ACCOUNT" "$WORKER_NAME" "$log_file"
cd "$BASE_DIR/bin"
set +e
"$MINER" --coin pearl -o "$POOL" -u "$KRYPTEX_ACCOUNT/$WORKER_NAME" 2>&1 | tee -a "$log_file"
result=("${PIPESTATUS[@]}")
set -e
printf 'PeakMiner exited: code %s. Log: %s\n' "${result[0]}" "$log_file" >&2
if (( result[0] != 0 )); then exit "${result[0]}"; fi
exit "${result[1]}"
