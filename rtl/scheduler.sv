`timescale 1ns/1ps

import qc_pkg::*;

module scheduler #(
    parameter int NUM_QUBITS = MAX_QUBITS
) (
    input  logic              clk_i,
    input  logic              rst_ni,

    input  logic              instr_valid_i,
    input  qc_instr_fields_t  instr_i,

    output logic              queue_pop_o,

    output logic              issue_valid_o,
    output qc_instr_fields_t  issue_instr_o,

    output logic              stall_o,
    output logic [NUM_QUBITS-1:0] qubit_busy_o
);

    localparam logic [DURATION_W-1:0] ONE_CYCLE = {{(DURATION_W-1){1'b0}}, 1'b1};

    logic [DURATION_W-1:0] busy_cnt_q [NUM_QUBITS];

    logic uses_target;
    logic uses_control;
    logic target_busy;
    logic control_busy;
    logic hazard;
    logic can_issue;

    logic [DURATION_W-1:0] operation_duration;

    assign operation_duration = (instr_i.duration == '0) ? ONE_CYCLE : instr_i.duration;

    always_comb begin
        uses_target  = 1'b0;
        uses_control = 1'b0;

        unique case (instr_i.opcode)
            OP_H,
            OP_X,
            OP_Z,
            OP_MEASURE,
            OP_RESET: begin
                uses_target  = 1'b1;
                uses_control = 1'b0;
            end

            OP_CNOT: begin
                uses_target  = 1'b1;
                uses_control = 1'b1;
            end

            default: begin
                uses_target  = 1'b0;
                uses_control = 1'b0;
            end
        endcase
    end

    assign target_busy  = uses_target  ? (busy_cnt_q[instr_i.target_qubit]  != '0) : 1'b0;
    assign control_busy = uses_control ? (busy_cnt_q[instr_i.control_qubit] != '0) : 1'b0;

    assign hazard    = target_busy || control_busy;
    assign can_issue = instr_valid_i && !hazard;

    assign queue_pop_o = can_issue;
    assign stall_o     = instr_valid_i && hazard;

    always_comb begin
        for (int i = 0; i < NUM_QUBITS; i++) begin
            qubit_busy_o[i] = (busy_cnt_q[i] != '0);
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            issue_valid_o <= 1'b0;
            issue_instr_o <= '0;

            for (int i = 0; i < NUM_QUBITS; i++) begin
                busy_cnt_q[i] <= '0;
            end
        end else begin
            issue_valid_o <= 1'b0;
            issue_instr_o <= '0;

            for (int i = 0; i < NUM_QUBITS; i++) begin
                if (busy_cnt_q[i] != '0) begin
                    busy_cnt_q[i] <= busy_cnt_q[i] - ONE_CYCLE;
                end
            end

            if (can_issue) begin
                issue_valid_o <= 1'b1;
                issue_instr_o <= instr_i;

                if (uses_target) begin
                    busy_cnt_q[instr_i.target_qubit] <= operation_duration;
                end

                if (uses_control) begin
                    busy_cnt_q[instr_i.control_qubit] <= operation_duration;
                end
            end
        end
    end

endmodule
