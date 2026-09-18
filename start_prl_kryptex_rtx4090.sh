#!/usr/bin/env bash
# PRL / PeakMiner on Vast.ai, RTX 4090 worker preset.
# Uses the shared launcher; mines all NVIDIA GPUs visible in the instance.
# Does not change GPU clocks, power limits or fans.
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export WORKER_NAME="${WORKER_NAME:-vast409001}"
exec bash "$SCRIPT_DIR/start_prl_kryptex_rtx4070s.sh"
