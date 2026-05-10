#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

mkdir -p results/synthesis_reports

LOG_FILE="results/synthesis_reports/quantum_controller_top_synth_yosys.log"

echo "============================================================" | tee "$LOG_FILE"
echo "Running Yosys synthesis for quantum_controller_top_synth" | tee -a "$LOG_FILE"
echo "============================================================" | tee -a "$LOG_FILE"

yosys -s scripts/synth_quantum_controller_top.ys 2>&1 | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "Synthesis completed" | tee -a "$LOG_FILE"
echo "Log saved to: $LOG_FILE" | tee -a "$LOG_FILE"
