#!/usr/bin/env bash

set -euo pipefail

TEST="${1:-tb_quantum_controller_top}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

mkdir -p results/simulation_logs
mkdir -p results/waveforms
mkdir -p obj_dir

run_test() {
    local TOP="$1"
    shift

    local BUILD_DIR="obj_dir/${TOP}"
    local LOG_FILE="results/simulation_logs/${TOP}.log"

    rm -rf "$BUILD_DIR"

    echo "============================================================" | tee "$LOG_FILE"
    echo "Running test: ${TOP}" | tee -a "$LOG_FILE"
    echo "============================================================" | tee -a "$LOG_FILE"

    verilator \
        --sv \
        --binary \
        --timing \
        --trace \
        --top-module "$TOP" \
        --Mdir "$BUILD_DIR" \
        "$@" 2>&1 | tee -a "$LOG_FILE"

    echo "" | tee -a "$LOG_FILE"
    echo "Starting simulation: ${TOP}" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"

    "${BUILD_DIR}/V${TOP}" 2>&1 | tee -a "$LOG_FILE"

    echo "" | tee -a "$LOG_FILE"
    echo "Test completed: ${TOP}" | tee -a "$LOG_FILE"
    echo "Log saved to: ${LOG_FILE}" | tee -a "$LOG_FILE"
}

if [[ "$TEST" == "all" ]]; then
    "$0" tb_qc_pkg
    "$0" tb_instruction_decoder
    "$0" tb_operation_queue
    "$0" tb_dependency_tracker
    "$0" tb_scheduler
    "$0" tb_execution_controller
    "$0" tb_measurement_controller
    "$0" tb_feedback_unit
    "$0" tb_quantum_controller_top
    exit 0
fi

case "$TEST" in
    tb_qc_pkg)
        run_test tb_qc_pkg \
            rtl/qc_pkg.sv \
            tb/tb_qc_pkg.sv
        ;;

    tb_instruction_decoder)
        run_test tb_instruction_decoder \
            rtl/qc_pkg.sv \
            rtl/instruction_decoder.sv \
            tb/tb_instruction_decoder.sv
        ;;

    tb_operation_queue)
        run_test tb_operation_queue \
            rtl/qc_pkg.sv \
            rtl/operation_queue.sv \
            tb/tb_operation_queue.sv
        ;;

    tb_dependency_tracker)
        run_test tb_dependency_tracker \
            rtl/qc_pkg.sv \
            rtl/dependency_tracker.sv \
            tb/tb_dependency_tracker.sv
        ;;

    tb_scheduler)
        run_test tb_scheduler \
            rtl/qc_pkg.sv \
            rtl/dependency_tracker.sv \
            rtl/scheduler.sv \
            tb/tb_scheduler.sv
        ;;

    tb_execution_controller)
        run_test tb_execution_controller \
            rtl/qc_pkg.sv \
            rtl/execution_controller.sv \
            tb/tb_execution_controller.sv
        ;;

    tb_measurement_controller)
        run_test tb_measurement_controller \
            rtl/qc_pkg.sv \
            rtl/measurement_controller.sv \
            tb/tb_measurement_controller.sv
        ;;

    tb_feedback_unit)
        run_test tb_feedback_unit \
            rtl/qc_pkg.sv \
            rtl/feedback_unit.sv \
            tb/tb_feedback_unit.sv
        ;;

    tb_quantum_controller_top)
        run_test tb_quantum_controller_top \
            rtl/qc_pkg.sv \
            rtl/instruction_decoder.sv \
            rtl/operation_queue.sv \
            rtl/dependency_tracker.sv \
            rtl/scheduler.sv \
            rtl/execution_controller.sv \
            rtl/measurement_controller.sv \
            rtl/feedback_unit.sv \
            rtl/quantum_controller_top.sv \
            tb/tb_quantum_controller_top.sv
        ;;

    *)
        echo "Unknown test: $TEST"
        echo ""
        echo "Available tests:"
        echo "  tb_qc_pkg"
        echo "  tb_instruction_decoder"
        echo "  tb_operation_queue"
        echo "  tb_dependency_tracker"
        echo "  tb_scheduler"
        echo "  tb_execution_controller"
        echo "  tb_measurement_controller"
        echo "  tb_feedback_unit"
        echo "  tb_quantum_controller_top"
        echo "  all"
        exit 1
        ;;
esac
