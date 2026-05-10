`timescale 1ns/1ps

import qc_pkg::*;

module scheduler #(
    parameter int NUM_QUBITS = MAX_QUBITS
) (
    input  logic              clk_i,
    input  logic              rst_ni,

    input  logic              instr_valid_i,
    input  qc_instr_fields_t  instr_i,
    input  logic              issue_ready_i,

    output logic              queue_pop_o,

    output logic              issue_valid_o,
    output qc_instr_fields_t  issue_instr_o,

    output logic              stall_o,
    output logic [NUM_QUBITS-1:0] qubit_busy_o
);

    localparam logic [DURATION_W-1:0] ONE_CYCLE = {{(DURATION_W-1){1'b0}}, 1'b1};

    logic [DURATION_W-1:0] busy_cnt_q [NUM_QUBITS];
    logic [DURATION_W-1:0] wait_cnt_q;

    logic [NUM_QUBITS-1:0] qubit_busy;

    logic tracker_uses_target;
    logic tracker_uses_control;
    logic [NUM_QUBITS-1:0] tracker_qubit_mask;
    logic tracker_target_busy;
    logic tracker_control_busy;
    logic tracker_dependency_hazard;
    logic tracker_independent;

    logic [DURATION_W-1:0] operation_duration;
    logic wait_active;
    logic can_issue;

    assign operation_duration = (instr_i.duration == '0) ? ONE_CYCLE : instr_i.duration;
    assign wait_active        = (wait_cnt_q != '0);

    always_comb begin
        for (int i = 0; i < NUM_QUBITS; i++) begin
            qubit_busy[i] = (busy_cnt_q[i] != '0);
        end
    end

    assign qubit_busy_o = qubit_busy;

    dependency_tracker #(
        .NUM_QUBITS(NUM_QUBITS)
    ) u_dependency_tracker (
        .instr_valid_i       (instr_valid_i),
        .instr_i             (instr_i),

        .qubit_busy_i        (qubit_busy),

        .uses_target_o       (tracker_uses_target),
        .uses_control_o      (tracker_uses_control),

        .qubit_mask_o        (tracker_qubit_mask),

        .target_busy_o       (tracker_target_busy),
        .control_busy_o      (tracker_control_busy),

        .dependency_hazard_o (tracker_dependency_hazard),
        .independent_o       (tracker_independent)
    );

    assign can_issue   = tracker_independent && issue_ready_i && !wait_active;
    assign queue_pop_o = can_issue;
    assign stall_o     = instr_valid_i &&
                          (wait_active ||
                           tracker_dependency_hazard ||
                           (tracker_independent && !issue_ready_i));

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            issue_valid_o <= 1'b0;
            issue_instr_o <= '0;
            wait_cnt_q    <= '0;

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

            if (wait_cnt_q != '0) begin
                wait_cnt_q <= wait_cnt_q - ONE_CYCLE;
            end

            if (can_issue) begin
                issue_valid_o <= 1'b1;
                issue_instr_o <= instr_i;

                if (instr_i.opcode == OP_WAIT) begin
                    wait_cnt_q <= operation_duration;
                end

                if (tracker_uses_target) begin
                    busy_cnt_q[instr_i.target_qubit] <= operation_duration;
                end

                if (tracker_uses_control) begin
                    busy_cnt_q[instr_i.control_qubit] <= operation_duration;
                end
            end
        end
    end

endmodule
