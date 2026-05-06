`timescale 1ns/1ps

import qc_pkg::*;

module execution_controller (
    input  logic             clk_i,
    input  logic             rst_ni,

    input  logic             issue_valid_i,
    input  qc_instr_fields_t issue_instr_i,
    output logic             issue_ready_o,

    output logic             command_valid_o,
    output qc_instr_fields_t command_instr_o,

    output logic             gate_cmd_o,
    output logic             measure_cmd_o,
    output logic             wait_cmd_o,
    output logic             reset_cmd_o,
    output logic             branch_cmd_o,
    output logic             nop_cmd_o,

    output logic             illegal_issue_o
);

    assign issue_ready_o = 1'b1;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            command_valid_o <= 1'b0;
            command_instr_o <= '0;

            gate_cmd_o      <= 1'b0;
            measure_cmd_o   <= 1'b0;
            wait_cmd_o      <= 1'b0;
            reset_cmd_o     <= 1'b0;
            branch_cmd_o    <= 1'b0;
            nop_cmd_o       <= 1'b0;

            illegal_issue_o <= 1'b0;
        end else begin
            command_valid_o <= 1'b0;
            command_instr_o <= '0;

            gate_cmd_o      <= 1'b0;
            measure_cmd_o   <= 1'b0;
            wait_cmd_o      <= 1'b0;
            reset_cmd_o     <= 1'b0;
            branch_cmd_o    <= 1'b0;
            nop_cmd_o       <= 1'b0;

            illegal_issue_o <= 1'b0;

            if (issue_valid_i && issue_ready_o) begin
                unique case (issue_instr_i.opcode)
                    OP_NOP: begin
                        command_valid_o <= 1'b0;
                        command_instr_o <= issue_instr_i;
                        nop_cmd_o       <= 1'b1;
                    end

                    OP_H,
                    OP_X,
                    OP_Z,
                    OP_CNOT: begin
                        command_valid_o <= 1'b1;
                        command_instr_o <= issue_instr_i;
                        gate_cmd_o      <= 1'b1;
                    end

                    OP_MEASURE: begin
                        command_valid_o <= 1'b1;
                        command_instr_o <= issue_instr_i;
                        measure_cmd_o   <= 1'b1;
                    end

                    OP_WAIT: begin
                        command_valid_o <= 1'b1;
                        command_instr_o <= issue_instr_i;
                        wait_cmd_o      <= 1'b1;
                    end

                    OP_RESET: begin
                        command_valid_o <= 1'b1;
                        command_instr_o <= issue_instr_i;
                        reset_cmd_o     <= 1'b1;
                    end

                    OP_BRANCH: begin
                        command_valid_o <= 1'b1;
                        command_instr_o <= issue_instr_i;
                        branch_cmd_o    <= 1'b1;
                    end

                    default: begin
                        command_valid_o <= 1'b0;
                        command_instr_o <= issue_instr_i;
                        illegal_issue_o <= 1'b1;
                    end
                endcase
            end
        end
    end

endmodule
