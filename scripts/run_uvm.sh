#!/usr/bin/env bash

set -euo pipefail

TEST="${1:-qc_smoke_test}"
SEED="${SEED:-1}"
SIM="${UVM_SIM:-auto}"
TIMEOUT_CYCLES="${TIMEOUT_CYCLES:-10000}"
DUMP_VCD="${DUMP_VCD:-1}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

LOG_DIR="results/uvm_logs"
WAVE_DIR="results/uvm_waveforms"
COV_DIR="results/uvm_coverage"
BUILD_DIR="obj_dir/uvm"

mkdir -p "$LOG_DIR" "$WAVE_DIR" "$COV_DIR" "$BUILD_DIR"

TESTS=(
    qc_smoke_test
    qc_single_gate_test
    qc_cnot_test
    qc_measure_test
    qc_wait_test
    qc_branch_test
    qc_invalid_opcode_test
    qc_random_test
    qc_dependency_stress_test
    qc_bell_test
    qc_ghz_test
    qc_grover_like_test
)

RTL_FILES=(
    rtl/qc_pkg.sv
    rtl/instruction_decoder.sv
    rtl/operation_queue.sv
    rtl/dependency_tracker.sv
    rtl/scheduler.sv
    rtl/execution_controller.sv
    rtl/measurement_controller.sv
    rtl/feedback_unit.sv
    rtl/quantum_controller_top.sv
)

UVM_FILES=(
    uvm/qc_if.sv
    uvm/qc_uvm_pkg.sv
    uvm/tb_qc_uvm_top.sv
)

usage() {
    echo "Usage: $0 <test|all|--list>"
    echo ""
    echo "Environment:"
    echo "  UVM_SIM=auto|questa|xcelium|vcs"
    echo "  SEED=<integer>"
    echo "  TIMEOUT_CYCLES=<integer>"
    echo "  DUMP_VCD=0|1"
    echo ""
    echo "Available tests:"
    for test_name in "${TESTS[@]}"; do
        echo "  ${test_name}"
    done
}

detect_simulator() {
    if [[ "$SIM" != "auto" ]]; then
        echo "$SIM"
        return
    fi

    if command -v vlog >/dev/null 2>&1 && command -v vsim >/dev/null 2>&1; then
        echo "questa"
        return
    fi

    if command -v xrun >/dev/null 2>&1; then
        echo "xcelium"
        return
    fi

    if command -v vcs >/dev/null 2>&1; then
        echo "vcs"
        return
    fi

    echo "none"
}

common_plusargs() {
    local wave_file="$1"

    echo "+UVM_TESTNAME=${TEST}"
    echo "+ntb_random_seed=${SEED}"
    echo "+TIMEOUT_CYCLES=${TIMEOUT_CYCLES}"
    echo "+WAVE_FILE=${wave_file}"

    if [[ "$DUMP_VCD" == "1" ]]; then
        echo "+DUMP_VCD"
    fi
}

run_questa() {
    local log_file="$LOG_DIR/${TEST}.log"
    local wave_file="$WAVE_DIR/${TEST}.vcd"
    local work_dir="$BUILD_DIR/questa_${TEST}"
    local plusargs

    mapfile -t plusargs < <(common_plusargs "$wave_file")

    rm -rf "$work_dir"
    mkdir -p "$work_dir"

    {
        echo "Running ${TEST} with Questa/ModelSim"
        echo "Seed: ${SEED}"
        echo "Log: ${log_file}"
        echo "Wave: ${wave_file}"
    } | tee "$log_file"

    vlib "$work_dir/work" 2>&1 | tee -a "$log_file"
    vlog \
        -sv \
        -uvm \
        -work "$work_dir/work" \
        +incdir+uvm \
        +incdir+rtl \
        "${RTL_FILES[@]}" \
        "${UVM_FILES[@]}" 2>&1 | tee -a "$log_file"

    vsim \
        -c \
        -sv_seed "$SEED" \
        -wlf "$WAVE_DIR/${TEST}.wlf" \
        -do "run -all; quit -f" \
        "$work_dir/work.tb_qc_uvm_top" \
        "${plusargs[@]}" 2>&1 | tee -a "$log_file"
}

run_xcelium() {
    local log_file="$LOG_DIR/${TEST}.log"
    local wave_file="$WAVE_DIR/${TEST}.vcd"
    local xrun_dir="$BUILD_DIR/xcelium_${TEST}"
    local plusargs

    mapfile -t plusargs < <(common_plusargs "$wave_file")

    rm -rf "$xrun_dir"
    mkdir -p "$xrun_dir"

    xrun \
        -64bit \
        -uvm \
        -sv \
        -access +rwc \
        -xmlibdirname "$xrun_dir" \
        -top tb_qc_uvm_top \
        -seed "$SEED" \
        +incdir+uvm \
        +incdir+rtl \
        "${RTL_FILES[@]}" \
        "${UVM_FILES[@]}" \
        "${plusargs[@]}" \
        -l "$log_file"
}

run_vcs() {
    local log_file="$LOG_DIR/${TEST}.log"
    local wave_file="$WAVE_DIR/${TEST}.vcd"
    local build_dir="$BUILD_DIR/vcs_${TEST}"
    local simv="$build_dir/simv"
    local plusargs

    mapfile -t plusargs < <(common_plusargs "$wave_file")

    rm -rf "$build_dir"
    mkdir -p "$build_dir"

    vcs \
        -full64 \
        -sverilog \
        -ntb_opts uvm \
        +incdir+uvm \
        +incdir+rtl \
        -top tb_qc_uvm_top \
        -o "$simv" \
        "${RTL_FILES[@]}" \
        "${UVM_FILES[@]}" \
        -l "$LOG_DIR/${TEST}_compile.log"

    "$simv" "${plusargs[@]}" -l "$log_file"
}

run_one() {
    local selected_sim

    selected_sim="$(detect_simulator)"

    if [[ "$selected_sim" == "none" ]]; then
        echo "No UVM-capable simulator found in PATH."
        echo "Install/configure Questa/ModelSim, Xcelium or VCS, or set UVM_SIM explicitly."
        echo "This script does not run UVM with Verilator."
        exit 2
    fi

    case "$selected_sim" in
        questa)
            run_questa
            ;;
        xcelium)
            run_xcelium
            ;;
        vcs)
            run_vcs
            ;;
        *)
            echo "Unsupported UVM_SIM value: ${selected_sim}"
            echo "Expected: auto, questa, xcelium, vcs"
            exit 1
            ;;
    esac
}

if [[ "$TEST" == "--list" ]]; then
    usage
    exit 0
fi

if [[ "$TEST" == "all" ]]; then
    for test_name in "${TESTS[@]}"; do
        "$0" "$test_name"
    done
    exit 0
fi

known_test=0
for test_name in "${TESTS[@]}"; do
    if [[ "$TEST" == "$test_name" ]]; then
        known_test=1
        break
    fi
done

if [[ "$known_test" != "1" ]]; then
    echo "Unknown UVM test: ${TEST}"
    echo ""
    usage
    exit 1
fi

run_one
