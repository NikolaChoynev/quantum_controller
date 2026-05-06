`timescale 1ns/1ps

import qc_pkg::*;

module quantum_controller_top #(
    parameter int QUEUE_DEPTH = 4
) (
    input  logic                    clk_i,
    input  logic                    rst_ni,

    input  logic [INSTR_W-1:0]      instr_i,
    input  logic                    instr_valid_i,
    output logic                    instr_ready_o,

    input  logic                    operation_pop_i,

    output qc_opcode_e              opcode_o,
    output logic [QUBIT_ID_W-1:0]   target_qubit_o,
    output logic [QUBIT_ID_W-1:0]   control_qubit_o,
    output logic [DURATION_W-1:0]   duration_o,
    output logic [FLAGS_W-1:0]      flags_o,

    output logic                    decoded_valid_o,
    output logic                    illegal_instr_o,

    output logic [$clog2(QUEUE_DEPTH+1)-1:0] queue_count_o
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

    logic                   queue_push;
    logic                   queue_full;
    logic                   queue_empty;
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

        .pop_i   (operation_pop_i),
        .instr_o (queue_instr),
        .empty_o (queue_empty),

        .count_o (queue_count_o)
    );

    assign opcode_o         = queue_empty ? OP_NOP : queue_instr.opcode;
    assign target_qubit_o   = queue_empty ? '0     : queue_instr.target_qubit;
    assign control_qubit_o  = queue_empty ? '0     : queue_instr.control_qubit;
    assign duration_o       = queue_empty ? '0     : queue_instr.duration;
    assign flags_o          = queue_empty ? '0     : queue_instr.flags;

    assign decoded_valid_o  = !queue_empty;
    assign illegal_instr_o  = illegal_q;

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
