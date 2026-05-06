`timescale 1ns/1ps

import qc_pkg::*;

module quantum_controller_top #(
    parameter int QUEUE_DEPTH = 4,
    parameter int NUM_QUBITS  = MAX_QUBITS
) (
    input  logic                    clk_i,
    input  logic                    rst_ni,

    input  logic [INSTR_W-1:0]      instr_i,
    input  logic                    instr_valid_i,
    output logic                    instr_ready_o,

    input  logic                    measurement_result_valid_i,
    input  logic                    measurement_result_i,

    output logic                    issue_valid_o,
    output qc_opcode_e              issue_opcode_o,
    output logic [QUBIT_ID_W-1:0]   issue_target_qubit_o,
    output logic [QUBIT_ID_W-1:0]   issue_control_qubit_o,
    output logic [DURATION_W-1:0]   issue_duration_o,
    output logic [FLAGS_W-1:0]      issue_flags_o,

    output logic                    command_valid_o,
    output qc_opcode_e              command_opcode_o,
    output logic [QUBIT_ID_W-1:0]   command_target_qubit_o,
    output logic [QUBIT_ID_W-1:0]   command_control_qubit_o,
    output logic [DURATION_W-1:0]   command_duration_o,
    output logic [FLAGS_W-1:0]      command_flags_o,

    output logic                    gate_cmd_o,
    output logic                    measure_cmd_o,
    output logic                    wait_cmd_o,
    output logic                    reset_cmd_o,
    output logic                    branch_cmd_o,
    output logic                    nop_cmd_o,

    output logic                    measure_request_valid_o,
    output logic [QUBIT_ID_W-1:0]   measure_qubit_o,
    output logic                    measurement_busy_o,

    output logic                    measurement_result_out_valid_o,
    output logic [QUBIT_ID_W-1:0]   measurement_result_qubit_o,
    output logic                    measurement_result_value_o,
    output logic [NUM_QUBITS-1:0]   measurement_valid_o,
    output logic [NUM_QUBITS-1:0]   measurement_results_o,
    output logic                    unexpected_measurement_result_o,

    output logic                    feedback_valid_o,
    output logic                    branch_taken_o,
    output logic [DURATION_W-1:0]   branch_target_o,
    output logic [QUBIT_ID_W-1:0]   feedback_qubit_o,
    output logic                    feedback_value_o,
    output logic                    condition_checked_o,
    output logic                    missing_measurement_o,

    output logic                    scheduler_stall_o,
    output logic                    illegal_instr_o,
    output logic                    illegal_issue_o,

    output logic [$clog2(QUEUE_DEPTH+1)-1:0] queue_count_o,
    output logic [NUM_QUBITS-1:0]             qubit_busy_o
);

    qc_opcode_e             dec_opcode;
    logic [QUBIT_ID_W-1:0]  dec_target_qubit;
    logic [QUBIT_ID_W-1:0]  dec_control_qubit;
    logic [DURATION_W-1:0]  dec_duration;
    logic [FLAGS_W-1:0]     dec_flags;
    logic                   dec_valid;
    logic                   dec_illegal;

    qc_instr_fields_t       decoded_instr;
    qc_instr_fields_t       queue_instr;
    qc_instr_fields_t       sched_issue_instr;
    qc_instr_fields_t       command_instr;

    logic                   queue_push;
    logic                   queue_full;
    logic                   queue_empty;
    logic                   queue_pop;

    logic                   sched_issue_valid;
    logic                   execution_ready;
    logic                   measurement_command_ready;
    logic                   illegal_q;

    instruction_decoder u_instruction_decoder (
        .instr_i         (instr_i),
        .opcode_o        (dec_opcode),
        .target_qubit_o  (dec_target_qubit),
        .control_qubit_o (dec_control_qubit),
        .duration_o      (dec_duration),
        .flags_o         (dec_flags),
        .valid_o         (dec_valid),
        .illegal_o       (dec_illegal)
    );

    assign decoded_instr.opcode        = dec_opcode;
    assign decoded_instr.target_qubit  = dec_target_qubit;
    assign decoded_instr.control_qubit = dec_control_qubit;
    assign decoded_instr.duration      = dec_duration;
    assign decoded_instr.flags         = dec_flags;
    assign decoded_instr.reserved      = '0;

    assign instr_ready_o = !queue_full;

    assign queue_push = instr_valid_i &&
                        instr_ready_o &&
                        dec_valid &&
                        !dec_illegal;

    operation_queue #(
        .DEPTH(QUEUE_DEPTH)
    ) u_operation_queue (
        .clk_i   (clk_i),
        .rst_ni  (rst_ni),

        .push_i  (queue_push),
        .instr_i (decoded_instr),
        .full_o  (queue_full),

        .pop_i   (queue_pop),
        .instr_o (queue_instr),
        .empty_o (queue_empty),

        .count_o (queue_count_o)
    );

    scheduler #(
        .NUM_QUBITS(NUM_QUBITS)
    ) u_scheduler (
        .clk_i         (clk_i),
        .rst_ni        (rst_ni),

        .instr_valid_i (!queue_empty),
        .instr_i       (queue_instr),

        .queue_pop_o   (queue_pop),

        .issue_valid_o (sched_issue_valid),
        .issue_instr_o (sched_issue_instr),

        .stall_o       (scheduler_stall_o),
        .qubit_busy_o  (qubit_busy_o)
    );

    execution_controller u_execution_controller (
        .clk_i           (clk_i),
        .rst_ni          (rst_ni),

        .issue_valid_i   (sched_issue_valid),
        .issue_instr_i   (sched_issue_instr),
        .issue_ready_o   (execution_ready),

        .command_valid_o (command_valid_o),
        .command_instr_o (command_instr),

        .gate_cmd_o      (gate_cmd_o),
        .measure_cmd_o   (measure_cmd_o),
        .wait_cmd_o      (wait_cmd_o),
        .reset_cmd_o     (reset_cmd_o),
        .branch_cmd_o    (branch_cmd_o),
        .nop_cmd_o       (nop_cmd_o),

        .illegal_issue_o (illegal_issue_o)
    );

    measurement_controller #(
        .NUM_QUBITS(NUM_QUBITS)
    ) u_measurement_controller (
        .clk_i                      (clk_i),
        .rst_ni                     (rst_ni),

        .command_valid_i            (command_valid_o),
        .command_instr_i            (command_instr),
        .command_ready_o            (measurement_command_ready),

        .measurement_result_valid_i (measurement_result_valid_i),
        .measurement_result_i       (measurement_result_i),

        .measure_request_valid_o    (measure_request_valid_o),
        .measure_qubit_o            (measure_qubit_o),

        .measurement_busy_o         (measurement_busy_o),

        .result_valid_o             (measurement_result_out_valid_o),
        .result_qubit_o             (measurement_result_qubit_o),
        .result_value_o             (measurement_result_value_o),

        .measurement_valid_o        (measurement_valid_o),
        .measurement_results_o      (measurement_results_o),

        .unexpected_result_o        (unexpected_measurement_result_o)
    );

    feedback_unit #(
        .NUM_QUBITS(NUM_QUBITS)
    ) u_feedback_unit (
        .clk_i                 (clk_i),
        .rst_ni                (rst_ni),

        .command_valid_i       (command_valid_o),
        .command_instr_i       (command_instr),
        .branch_cmd_i          (branch_cmd_o),

        .measurement_valid_i   (measurement_valid_o),
        .measurement_results_i (measurement_results_o),

        .feedback_valid_o      (feedback_valid_o),
        .branch_taken_o        (branch_taken_o),
        .branch_target_o       (branch_target_o),

        .feedback_qubit_o      (feedback_qubit_o),
        .feedback_value_o      (feedback_value_o),

        .condition_checked_o   (condition_checked_o),
        .missing_measurement_o (missing_measurement_o)
    );

    assign issue_valid_o         = sched_issue_valid;
    assign issue_opcode_o        = sched_issue_valid ? sched_issue_instr.opcode        : OP_NOP;
    assign issue_target_qubit_o  = sched_issue_valid ? sched_issue_instr.target_qubit  : '0;
    assign issue_control_qubit_o = sched_issue_valid ? sched_issue_instr.control_qubit : '0;
    assign issue_duration_o      = sched_issue_valid ? sched_issue_instr.duration      : '0;
    assign issue_flags_o         = sched_issue_valid ? sched_issue_instr.flags         : '0;

    assign command_opcode_o        = command_valid_o ? command_instr.opcode        : OP_NOP;
    assign command_target_qubit_o  = command_valid_o ? command_instr.target_qubit  : '0;
    assign command_control_qubit_o = command_valid_o ? command_instr.control_qubit : '0;
    assign command_duration_o      = command_valid_o ? command_instr.duration      : '0;
    assign command_flags_o         = command_valid_o ? command_instr.flags         : '0;

    assign illegal_instr_o = illegal_q;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            illegal_q <= 1'b0;
        end else begin
            illegal_q <= 1'b0;

            if (instr_valid_i && instr_ready_o && dec_illegal) begin
                illegal_q <= 1'b1;
            end
        end
    end

endmodule
