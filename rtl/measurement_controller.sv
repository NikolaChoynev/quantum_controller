`timescale 1ns/1ps

import qc_pkg::*;

module measurement_controller #(
    parameter int NUM_QUBITS = MAX_QUBITS
) (
    input  logic                    clk_i,
    input  logic                    rst_ni,

    input  logic                    command_valid_i,
    input  qc_instr_fields_t        command_instr_i,
    output logic                    command_ready_o,

    input  logic                    measurement_result_valid_i,
    input  logic                    measurement_result_i,

    output logic                    measure_request_valid_o,
    output logic [QUBIT_ID_W-1:0]   measure_qubit_o,

    output logic                    measurement_busy_o,

    output logic                    result_valid_o,
    output logic [QUBIT_ID_W-1:0]   result_qubit_o,
    output logic                    result_value_o,

    output logic [NUM_QUBITS-1:0]   measurement_valid_o,
    output logic [NUM_QUBITS-1:0]   measurement_results_o,

    output logic                    unexpected_result_o
);

    logic                  pending_q;
    logic [QUBIT_ID_W-1:0] pending_qubit_q;

    assign command_ready_o    = !pending_q;
    assign measurement_busy_o = pending_q;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            pending_q               <= 1'b0;
            pending_qubit_q         <= '0;

            measure_request_valid_o <= 1'b0;
            measure_qubit_o         <= '0;

            result_valid_o          <= 1'b0;
            result_qubit_o          <= '0;
            result_value_o          <= 1'b0;

            measurement_valid_o     <= '0;
            measurement_results_o   <= '0;

            unexpected_result_o     <= 1'b0;
        end else begin
            measure_request_valid_o <= 1'b0;

            result_valid_o          <= 1'b0;
            result_qubit_o          <= '0;
            result_value_o          <= 1'b0;

            unexpected_result_o     <= 1'b0;

            if (command_valid_i && command_ready_o) begin
                if (command_instr_i.opcode == OP_MEASURE) begin
                    pending_q               <= 1'b1;
                    pending_qubit_q         <= command_instr_i.target_qubit;

                    measure_request_valid_o <= 1'b1;
                    measure_qubit_o         <= command_instr_i.target_qubit;
                end
            end

            if (measurement_result_valid_i) begin
                if (pending_q) begin
                    pending_q <= 1'b0;

                    result_valid_o <= 1'b1;
                    result_qubit_o <= pending_qubit_q;
                    result_value_o <= measurement_result_i;

                    measurement_valid_o[pending_qubit_q]   <= 1'b1;
                    measurement_results_o[pending_qubit_q] <= measurement_result_i;
                end else begin
                    unexpected_result_o <= 1'b1;
                end
            end
        end
    end

endmodule
