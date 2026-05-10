`timescale 1ns/1ps

import qc_pkg::*;

module feedback_unit #(
    parameter int NUM_QUBITS = MAX_QUBITS
) (
    input  logic                    clk_i,
    input  logic                    rst_ni,

    input  logic                    command_valid_i,
    input  qc_instr_fields_t        command_instr_i,
    input  logic                    branch_cmd_i,

    input  logic [NUM_QUBITS-1:0]   measurement_valid_i,
    input  logic [NUM_QUBITS-1:0]   measurement_results_i,

    output logic                    feedback_valid_o,
    output logic                    branch_taken_o,
    output logic [DURATION_W-1:0]   branch_target_o,

    output logic [QUBIT_ID_W-1:0]   feedback_qubit_o,
    output logic                    feedback_value_o,

    output logic                    condition_checked_o,
    output logic                    missing_measurement_o
);

    logic [QUBIT_ID_W-1:0] selected_qubit;
    logic                  selected_valid;
    logic                  selected_result;
    logic                  conditional_branch;
    logic                  expected_value;

    assign selected_qubit     = command_instr_i.target_qubit;
    assign selected_valid     = measurement_valid_i[selected_qubit];
    assign selected_result    = measurement_results_i[selected_qubit];

    assign conditional_branch = command_instr_i.flags[FLAG_CONDITIONAL_BIT] |
                                command_instr_i.flags[FLAG_FEEDBACK_BIT];

    assign expected_value     = command_instr_i.flags[FLAG_EXPECTED_BIT];

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            feedback_valid_o      <= 1'b0;
            branch_taken_o        <= 1'b0;
            branch_target_o       <= '0;

            feedback_qubit_o      <= '0;
            feedback_value_o      <= 1'b0;

            condition_checked_o   <= 1'b0;
            missing_measurement_o <= 1'b0;
        end else begin
            feedback_valid_o      <= 1'b0;
            branch_taken_o        <= 1'b0;
            branch_target_o       <= '0;

            feedback_qubit_o      <= '0;
            feedback_value_o      <= 1'b0;

            condition_checked_o   <= 1'b0;
            missing_measurement_o <= 1'b0;

            if (command_valid_i && branch_cmd_i &&
                command_instr_i.opcode == OP_BRANCH &&
                command_instr_i.flags[FLAG_VALID_BIT]) begin

                feedback_valid_o <= 1'b1;
                feedback_qubit_o <= selected_qubit;
                branch_target_o  <= command_instr_i.duration;

                if (conditional_branch) begin
                    if (selected_valid) begin
                        condition_checked_o <= 1'b1;
                        feedback_value_o    <= selected_result;
                        branch_taken_o      <= (selected_result == expected_value);
                    end else begin
                        missing_measurement_o <= 1'b1;
                        branch_taken_o        <= 1'b0;
                    end
                end else begin
                    condition_checked_o <= 1'b0;
                    feedback_value_o    <= 1'b0;
                    branch_taken_o      <= 1'b1;
                end
            end
        end
    end

endmodule
