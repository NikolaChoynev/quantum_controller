`timescale 1ns/1ps

import qc_pkg::*;

module tb_feedback_unit;

    localparam int NUM_QUBITS = 16;

    logic clk_i;
    logic rst_ni;

    logic command_valid_i;
    qc_instr_fields_t command_instr_i;
    logic branch_cmd_i;

    logic [NUM_QUBITS-1:0] measurement_valid_i;
    logic [NUM_QUBITS-1:0] measurement_results_i;

    logic feedback_valid_o;
    logic branch_taken_o;
    logic [DURATION_W-1:0] branch_target_o;

    logic [QUBIT_ID_W-1:0] feedback_qubit_o;
    logic feedback_value_o;

    logic condition_checked_o;
    logic missing_measurement_o;

    feedback_unit #(
        .NUM_QUBITS(NUM_QUBITS)
    ) dut (
        .clk_i                 (clk_i),
        .rst_ni                (rst_ni),

        .command_valid_i       (command_valid_i),
        .command_instr_i       (command_instr_i),
        .branch_cmd_i          (branch_cmd_i),

        .measurement_valid_i   (measurement_valid_i),
        .measurement_results_i (measurement_results_i),

        .feedback_valid_o      (feedback_valid_o),
        .branch_taken_o        (branch_taken_o),
        .branch_target_o       (branch_target_o),

        .feedback_qubit_o      (feedback_qubit_o),
        .feedback_value_o      (feedback_value_o),

        .condition_checked_o   (condition_checked_o),
        .missing_measurement_o (missing_measurement_o)
    );

    initial begin
        clk_i = 1'b0;
        forever #5 clk_i = ~clk_i;
    end

    function automatic qc_instr_fields_t make_branch(
        input logic [QUBIT_ID_W-1:0] qubit,
        input logic [DURATION_W-1:0] branch_target,
        input logic [FLAGS_W-1:0] flags
    );
        qc_instr_fields_t tmp;

        tmp.opcode        = OP_BRANCH;
        tmp.target_qubit  = qubit;
        tmp.control_qubit = '0;
        tmp.duration      = branch_target;
        tmp.flags         = flags;
        tmp.reserved      = '0;

        return tmp;
    endfunction

    task automatic send_branch(
        input logic [QUBIT_ID_W-1:0] qubit,
        input logic [DURATION_W-1:0] branch_target,
        input logic [FLAGS_W-1:0] flags
    );
        begin
            @(negedge clk_i);
            command_instr_i = make_branch(qubit, branch_target, flags);
            command_valid_i = 1'b1;
            branch_cmd_i    = 1'b1;

            @(posedge clk_i);
            #1;

            command_valid_i = 1'b0;
            branch_cmd_i    = 1'b0;
            command_instr_i = '0;
        end
    endtask

    initial begin
        $dumpfile("results/waveforms/feedback_unit.vcd");
        $dumpvars(0, tb_feedback_unit);

        command_valid_i       = 1'b0;
        command_instr_i       = '0;
        branch_cmd_i          = 1'b0;
        measurement_valid_i   = '0;
        measurement_results_i = '0;
        rst_ni                = 1'b0;

        repeat (2) @(negedge clk_i);
        rst_ni = 1'b1;
        #1;

        if (feedback_valid_o != 1'b0)      $fatal(1, "Feedback valid should be 0 after reset");
        if (branch_taken_o != 1'b0)        $fatal(1, "Branch taken should be 0 after reset");
        if (missing_measurement_o != 1'b0) $fatal(1, "Missing measurement should be 0 after reset");

        $display("Reset test PASSED");

        // --------------------------------------------------------
        // Test 1: Conditional branch on q3, expected 1, stored result 1.
        // Expected: branch taken.
        // flags = 4'b1101:
        // valid=1, conditional=1, feedback=0, expected=1
        // --------------------------------------------------------
        measurement_valid_i[3]   = 1'b1;
        measurement_results_i[3] = 1'b1;

        send_branch(4'd3, 12'd25, 4'b1101);

        $display("Test 1: Conditional branch q3 expected 1, result 1");
        $display("feedback=%0b taken=%0b target=%0d qubit=%0d value=%0b checked=%0b missing=%0b",
                 feedback_valid_o,
                 branch_taken_o,
                 branch_target_o,
                 feedback_qubit_o,
                 feedback_value_o,
                 condition_checked_o,
                 missing_measurement_o);

        if (feedback_valid_o != 1'b1)      $fatal(1, "Test 1 failed: feedback_valid expected");
        if (branch_taken_o != 1'b1)        $fatal(1, "Test 1 failed: branch should be taken");
        if (branch_target_o != 12'd25)     $fatal(1, "Test 1 failed: branch target mismatch");
        if (feedback_qubit_o != 4'd3)      $fatal(1, "Test 1 failed: qubit mismatch");
        if (feedback_value_o != 1'b1)      $fatal(1, "Test 1 failed: feedback value mismatch");
        if (condition_checked_o != 1'b1)   $fatal(1, "Test 1 failed: condition should be checked");

        $display("Conditional branch taken test PASSED");

        // --------------------------------------------------------
        // Test 2: Conditional branch on q3, expected 1, stored result 0.
        // Expected: branch not taken.
        // --------------------------------------------------------
        measurement_valid_i[3]   = 1'b1;
        measurement_results_i[3] = 1'b0;

        send_branch(4'd3, 12'd25, 4'b1101);

        $display("Test 2: Conditional branch q3 expected 1, result 0");
        $display("feedback=%0b taken=%0b value=%0b checked=%0b missing=%0b",
                 feedback_valid_o,
                 branch_taken_o,
                 feedback_value_o,
                 condition_checked_o,
                 missing_measurement_o);

        if (feedback_valid_o != 1'b1)      $fatal(1, "Test 2 failed: feedback_valid expected");
        if (branch_taken_o != 1'b0)        $fatal(1, "Test 2 failed: branch should not be taken");
        if (feedback_value_o != 1'b0)      $fatal(1, "Test 2 failed: feedback value mismatch");
        if (condition_checked_o != 1'b1)   $fatal(1, "Test 2 failed: condition should be checked");

        $display("Conditional branch not taken test PASSED");

        // --------------------------------------------------------
        // Test 3: Conditional branch on q5, but no measurement result exists.
        // Expected: missing measurement.
        // --------------------------------------------------------
        measurement_valid_i[5]   = 1'b0;
        measurement_results_i[5] = 1'b0;

        send_branch(4'd5, 12'd12, 4'b1101);

        $display("Test 3: Conditional branch q5 without measurement");
        $display("feedback=%0b taken=%0b missing=%0b checked=%0b",
                 feedback_valid_o,
                 branch_taken_o,
                 missing_measurement_o,
                 condition_checked_o);

        if (feedback_valid_o != 1'b1)       $fatal(1, "Test 3 failed: feedback_valid expected");
        if (branch_taken_o != 1'b0)         $fatal(1, "Test 3 failed: branch should not be taken");
        if (missing_measurement_o != 1'b1)  $fatal(1, "Test 3 failed: missing measurement expected");
        if (condition_checked_o != 1'b0)    $fatal(1, "Test 3 failed: condition should not be checked");

        $display("Missing measurement test PASSED");

        // --------------------------------------------------------
        // Test 4: Unconditional branch.
        // flags = 4'b1000:
        // valid=1, conditional=0, feedback=0, expected=0
        // Expected: branch taken without checking measurement.
        // --------------------------------------------------------
        measurement_valid_i = '0;
        measurement_results_i = '0;

        send_branch(4'd0, 12'd7, 4'b1000);

        $display("Test 4: Unconditional branch");
        $display("feedback=%0b taken=%0b target=%0d checked=%0b missing=%0b",
                 feedback_valid_o,
                 branch_taken_o,
                 branch_target_o,
                 condition_checked_o,
                 missing_measurement_o);

        if (feedback_valid_o != 1'b1)       $fatal(1, "Test 4 failed: feedback_valid expected");
        if (branch_taken_o != 1'b1)         $fatal(1, "Test 4 failed: unconditional branch should be taken");
        if (branch_target_o != 12'd7)       $fatal(1, "Test 4 failed: branch target mismatch");
        if (condition_checked_o != 1'b0)    $fatal(1, "Test 4 failed: condition should not be checked");
        if (missing_measurement_o != 1'b0)  $fatal(1, "Test 4 failed: no missing measurement expected");

        $display("Unconditional branch test PASSED");

        // --------------------------------------------------------
        // Test 5: command_valid=0 should do nothing.
        // --------------------------------------------------------
        @(negedge clk_i);
        command_instr_i = make_branch(4'd3, 12'd5, 4'b1101);
        command_valid_i = 1'b0;
        branch_cmd_i    = 1'b1;

        @(posedge clk_i);
        #1;

        $display("Test 5: branch_cmd without command_valid");
        $display("feedback=%0b taken=%0b",
                 feedback_valid_o,
                 branch_taken_o);

        if (feedback_valid_o != 1'b0)       $fatal(1, "Test 5 failed: feedback should not be valid");
        if (branch_taken_o != 1'b0)         $fatal(1, "Test 5 failed: branch should not be taken");

        $display("Invalid command_valid test PASSED");

        $display("feedback_unit test PASSED");
        $finish;
    end

endmodule
