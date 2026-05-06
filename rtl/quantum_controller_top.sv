`timescale 1ns/1ps

import qc_pkg::*;

module quantum_controller_top (
    input  logic                    clk_i,
    input  logic                    rst_ni,

    input  logic [INSTR_W-1:0]      instr_i,
    input  logic                    instr_valid_i,
    output logic                    instr_ready_o,

    output qc_opcode_e              opcode_o,
    output logic [QUBIT_ID_W-1:0]   target_qubit_o,
    output logic [QUBIT_ID_W-1:0]   control_qubit_o,
    output logic [DURATION_W-1:0]   duration_o,
    output logic [FLAGS_W-1:0]      flags_o,

    output logic                    decoded_valid_o,
    output logic                    illegal_instr_o
);

    qc_opcode_e             dec_opcode;
    logic [QUBIT_ID_W-1:0]  dec_target_qubit;
    logic [QUBIT_ID_W-1:0]  dec_control_qubit;
    logic [DURATION_W-1:0]  dec_duration;
    logic [FLAGS_W-1:0]     dec_flags;
    logic                   dec_valid;
    logic                   dec_illegal;

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

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            instr_ready_o     <= 1'b1;

            opcode_o          <= OP_NOP;
            target_qubit_o    <= '0;
            control_qubit_o   <= '0;
            duration_o        <= '0;
            flags_o           <= '0;

            decoded_valid_o   <= 1'b0;
            illegal_instr_o   <= 1'b0;
        end else begin
            instr_ready_o     <= 1'b1;

            decoded_valid_o   <= 1'b0;
            illegal_instr_o   <= 1'b0;

            if (instr_valid_i && instr_ready_o) begin
                opcode_o        <= dec_opcode;
                target_qubit_o  <= dec_target_qubit;
                control_qubit_o <= dec_control_qubit;
                duration_o      <= dec_duration;
                flags_o         <= dec_flags;

                decoded_valid_o <= dec_valid && !dec_illegal;
                illegal_instr_o <= dec_illegal;
            end
        end
    end

endmodule
