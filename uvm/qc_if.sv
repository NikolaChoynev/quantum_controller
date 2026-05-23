`timescale 1ns/1ps

`ifndef QC_IF_SV
`define QC_IF_SV

interface qc_if #(
    parameter int QUEUE_DEPTH = 4,
    parameter int NUM_QUBITS  = qc_pkg::MAX_QUBITS
) (
    input logic clk_i
);

    import qc_pkg::*;

    logic                    rst_ni;

    logic [INSTR_W-1:0]      instr_i;
    logic                    instr_valid_i;
    logic                    instr_ready_o;

    logic                    measurement_result_valid_i;
    logic                    measurement_result_i;

    logic                    issue_valid_o;
    qc_opcode_e              issue_opcode_o;
    logic [QUBIT_ID_W-1:0]   issue_target_qubit_o;
    logic [QUBIT_ID_W-1:0]   issue_control_qubit_o;
    logic [DURATION_W-1:0]   issue_duration_o;
    logic [FLAGS_W-1:0]      issue_flags_o;

    logic                    command_valid_o;
    qc_opcode_e              command_opcode_o;
    logic [QUBIT_ID_W-1:0]   command_target_qubit_o;
    logic [QUBIT_ID_W-1:0]   command_control_qubit_o;
    logic [DURATION_W-1:0]   command_duration_o;
    logic [FLAGS_W-1:0]      command_flags_o;

    logic                    gate_cmd_o;
    logic                    measure_cmd_o;
    logic                    wait_cmd_o;
    logic                    reset_cmd_o;
    logic                    branch_cmd_o;
    logic                    nop_cmd_o;

    logic                    measure_request_valid_o;
    logic [QUBIT_ID_W-1:0]   measure_qubit_o;
    logic                    measurement_busy_o;

    logic                    measurement_result_out_valid_o;
    logic [QUBIT_ID_W-1:0]   measurement_result_qubit_o;
    logic                    measurement_result_value_o;
    logic [NUM_QUBITS-1:0]   measurement_valid_o;
    logic [NUM_QUBITS-1:0]   measurement_results_o;
    logic                    unexpected_measurement_result_o;

    logic                    feedback_valid_o;
    logic                    branch_taken_o;
    logic [DURATION_W-1:0]   branch_target_o;
    logic [QUBIT_ID_W-1:0]   feedback_qubit_o;
    logic                    feedback_value_o;
    logic                    condition_checked_o;
    logic                    missing_measurement_o;

    logic                    scheduler_stall_o;
    logic                    illegal_instr_o;
    logic                    illegal_issue_o;

    logic [$clog2(QUEUE_DEPTH+1)-1:0] queue_count_o;
    logic [NUM_QUBITS-1:0]           qubit_busy_o;

    clocking drv_cb @(posedge clk_i);
        default input #1step output #1ns;

        output rst_ni;
        output instr_i;
        output instr_valid_i;
        output measurement_result_valid_i;
        output measurement_result_i;

        input  instr_ready_o;
        input  measure_request_valid_o;
        input  measure_qubit_o;
        input  measurement_busy_o;
        input  feedback_valid_o;
        input  branch_taken_o;
    endclocking

    clocking mon_cb @(posedge clk_i);
        default input #1step output #1ns;

        input rst_ni;

        input instr_i;
        input instr_valid_i;
        input instr_ready_o;

        input measurement_result_valid_i;
        input measurement_result_i;

        input issue_valid_o;
        input issue_opcode_o;
        input issue_target_qubit_o;
        input issue_control_qubit_o;
        input issue_duration_o;
        input issue_flags_o;

        input command_valid_o;
        input command_opcode_o;
        input command_target_qubit_o;
        input command_control_qubit_o;
        input command_duration_o;
        input command_flags_o;

        input gate_cmd_o;
        input measure_cmd_o;
        input wait_cmd_o;
        input reset_cmd_o;
        input branch_cmd_o;
        input nop_cmd_o;

        input measure_request_valid_o;
        input measure_qubit_o;
        input measurement_busy_o;

        input measurement_result_out_valid_o;
        input measurement_result_qubit_o;
        input measurement_result_value_o;
        input measurement_valid_o;
        input measurement_results_o;
        input unexpected_measurement_result_o;

        input feedback_valid_o;
        input branch_taken_o;
        input branch_target_o;
        input feedback_qubit_o;
        input feedback_value_o;
        input condition_checked_o;
        input missing_measurement_o;

        input scheduler_stall_o;
        input illegal_instr_o;
        input illegal_issue_o;

        input queue_count_o;
        input qubit_busy_o;
    endclocking

    modport dut (
        input  clk_i,
        input  rst_ni,
        input  instr_i,
        input  instr_valid_i,
        output instr_ready_o,
        input  measurement_result_valid_i,
        input  measurement_result_i,
        output issue_valid_o,
        output issue_opcode_o,
        output issue_target_qubit_o,
        output issue_control_qubit_o,
        output issue_duration_o,
        output issue_flags_o,
        output command_valid_o,
        output command_opcode_o,
        output command_target_qubit_o,
        output command_control_qubit_o,
        output command_duration_o,
        output command_flags_o,
        output gate_cmd_o,
        output measure_cmd_o,
        output wait_cmd_o,
        output reset_cmd_o,
        output branch_cmd_o,
        output nop_cmd_o,
        output measure_request_valid_o,
        output measure_qubit_o,
        output measurement_busy_o,
        output measurement_result_out_valid_o,
        output measurement_result_qubit_o,
        output measurement_result_value_o,
        output measurement_valid_o,
        output measurement_results_o,
        output unexpected_measurement_result_o,
        output feedback_valid_o,
        output branch_taken_o,
        output branch_target_o,
        output feedback_qubit_o,
        output feedback_value_o,
        output condition_checked_o,
        output missing_measurement_o,
        output scheduler_stall_o,
        output illegal_instr_o,
        output illegal_issue_o,
        output queue_count_o,
        output qubit_busy_o
    );

    modport driver (
        clocking drv_cb,
        input clk_i
    );

    modport monitor (
        clocking mon_cb,
        input clk_i
    );

endinterface : qc_if

`endif
