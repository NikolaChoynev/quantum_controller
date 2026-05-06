`timescale 1ns/1ps

import qc_pkg::*;

module instruction_decoder (
    input  logic [INSTR_W-1:0]      instr_i,

    output qc_opcode_e              opcode_o,
    output logic [QUBIT_ID_W-1:0]   target_qubit_o,
    output logic [QUBIT_ID_W-1:0]   control_qubit_o,
    output logic [DURATION_W-1:0]   duration_o,
    output logic [FLAGS_W-1:0]      flags_o,
    output logic                    valid_o,
    output logic                    illegal_o
);

    qc_instr_t instr_decoded;

    assign instr_decoded.raw = instr_i;

    assign opcode_o        = instr_decoded.fields.opcode;
    assign target_qubit_o  = instr_decoded.fields.target_qubit;
    assign control_qubit_o = instr_decoded.fields.control_qubit;
    assign duration_o      = instr_decoded.fields.duration;
    assign flags_o         = instr_decoded.fields.flags;

    // In the selected instruction format, flags[3] is used as valid bit.
    assign valid_o = instr_decoded.fields.flags[3];

    always_comb begin
        illegal_o = 1'b0;

        unique case (instr_decoded.fields.opcode)
            OP_NOP,
            OP_H,
            OP_X,
            OP_Z,
            OP_CNOT,
            OP_MEASURE,
            OP_WAIT,
            OP_RESET,
            OP_BRANCH: begin
                illegal_o = 1'b0;
            end

            default: begin
                illegal_o = 1'b1;
            end
        endcase
    end

endmodule
