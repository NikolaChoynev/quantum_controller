`timescale 1ns/1ps

import qc_pkg::*;

module tb_execution_controller;

    logic clk_i;
    logic rst_ni;

    logic issue_valid_i;
    qc_instr_fields_t issue_instr_i;
    logic issue_ready_o;

    logic command_valid_o;
    qc_instr_fields_t command_instr_o;

    logic gate_cmd_o;
    logic measure_cmd_o;
    logic wait_cmd_o;
    logic reset_cmd_o;
    logic branch_cmd_o;
    logic nop_cmd_o;

    logic illegal_issue_o;

    execution_controller dut (
        .clk_i           (clk_i),
        .rst_ni          (rst_ni),

        .issue_valid_i   (issue_valid_i),
        .issue_instr_i   (issue_instr_i),
        .issue_ready_o   (issue_ready_o),

        .command_valid_o (command_valid_o),
        .command_instr_o (command_instr_o),

        .gate_cmd_o      (gate_cmd_o),
        .measure_cmd_o   (measure_cmd_o),
        .wait_cmd_o      (wait_cmd_o),
        .reset_cmd_o     (reset_cmd_o),
        .branch_cmd_o    (branch_cmd_o),
        .nop_cmd_o       (nop_cmd_o),

        .illegal_issue_o (illegal_issue_o)
    );

    initial begin
        clk_i = 1'b0;
        forever #5 clk_i = ~clk_i;
    end

    function automatic qc_instr_fields_t make_instr(
        input qc_opcode_e opcode,
        input logic [QUBIT_ID_W-1:0] target,
        input logic [QUBIT_ID_W-1:0] control,
        input logic [DURATION_W-1:0] duration
    );
        qc_instr_fields_t tmp;

        tmp.opcode        = opcode;
        tmp.target_qubit  = target;
        tmp.control_qubit = control;
        tmp.duration      = duration;
        tmp.flags         = 4'b1000;
        tmp.reserved      = '0;

        return tmp;
    endfunction

    task automatic send_issue(input qc_instr_fields_t instr);
        begin
            @(negedge clk_i);
            issue_instr_i  = instr;
            issue_valid_i  = 1'b1;

            @(posedge clk_i);
            #1;

            issue_valid_i  = 1'b0;
            issue_instr_i  = '0;
        end
    endtask

    initial begin
        $dumpfile("results/waveforms/execution_controller.vcd");
        $dumpvars(0, tb_execution_controller);

        issue_valid_i = 1'b0;
        issue_instr_i = '0;
        rst_ni        = 1'b0;

        repeat (2) @(negedge clk_i);
        rst_ni = 1'b1;
        #1;

        if (issue_ready_o != 1'b1)     $fatal(1, "Execution controller should be ready after reset");
        if (command_valid_o != 1'b0)   $fatal(1, "Command valid should be 0 after reset");
        if (illegal_issue_o != 1'b0)   $fatal(1, "Illegal issue should be 0 after reset");

        $display("Reset test PASSED");

        // --------------------------------------------------------
        // Test 1: H q0 should generate a gate command.
        // --------------------------------------------------------
        send_issue(make_instr(OP_H, 4'd0, 4'd0, 12'd4));

        $display("Test 1: H q0");
        $display("cmd_valid=%0b gate=%0b opcode=%0h target=%0d duration=%0d",
                 command_valid_o, gate_cmd_o,
                 command_instr_o.opcode,
                 command_instr_o.target_qubit,
                 command_instr_o.duration);

        if (command_valid_o != 1'b1)        $fatal(1, "Test 1 failed: command_valid expected");
        if (gate_cmd_o != 1'b1)             $fatal(1, "Test 1 failed: gate_cmd expected");
        if (command_instr_o.opcode != OP_H) $fatal(1, "Test 1 failed: opcode mismatch");
        if (command_instr_o.target_qubit != 4'd0) $fatal(1, "Test 1 failed: target mismatch");

        $display("H gate command test PASSED");

        // --------------------------------------------------------
        // Test 2: CNOT q1, q3 should generate a gate command.
        // --------------------------------------------------------
        send_issue(make_instr(OP_CNOT, 4'd1, 4'd3, 12'd8));

        $display("Test 2: CNOT q1, q3");
        $display("cmd_valid=%0b gate=%0b opcode=%0h target=%0d control=%0d",
                 command_valid_o, gate_cmd_o,
                 command_instr_o.opcode,
                 command_instr_o.target_qubit,
                 command_instr_o.control_qubit);

        if (command_valid_o != 1'b1)              $fatal(1, "Test 2 failed: command_valid expected");
        if (gate_cmd_o != 1'b1)                   $fatal(1, "Test 2 failed: gate_cmd expected");
        if (command_instr_o.opcode != OP_CNOT)    $fatal(1, "Test 2 failed: opcode mismatch");
        if (command_instr_o.target_qubit != 4'd1) $fatal(1, "Test 2 failed: target mismatch");
        if (command_instr_o.control_qubit != 4'd3)$fatal(1, "Test 2 failed: control mismatch");

        $display("CNOT gate command test PASSED");

        // --------------------------------------------------------
        // Test 3: MEASURE q2 should generate a measure command.
        // --------------------------------------------------------
        send_issue(make_instr(OP_MEASURE, 4'd2, 4'd0, 12'd6));

        $display("Test 3: MEASURE q2");
        $display("cmd_valid=%0b measure=%0b opcode=%0h target=%0d",
                 command_valid_o, measure_cmd_o,
                 command_instr_o.opcode,
                 command_instr_o.target_qubit);

        if (command_valid_o != 1'b1)                $fatal(1, "Test 3 failed: command_valid expected");
        if (measure_cmd_o != 1'b1)                  $fatal(1, "Test 3 failed: measure_cmd expected");
        if (command_instr_o.opcode != OP_MEASURE)   $fatal(1, "Test 3 failed: opcode mismatch");
        if (command_instr_o.target_qubit != 4'd2)   $fatal(1, "Test 3 failed: target mismatch");

        $display("MEASURE command test PASSED");

        // --------------------------------------------------------
        // Test 4: WAIT should generate a wait command.
        // --------------------------------------------------------
        send_issue(make_instr(OP_WAIT, 4'd0, 4'd0, 12'd10));

        $display("Test 4: WAIT");
        $display("cmd_valid=%0b wait=%0b duration=%0d",
                 command_valid_o, wait_cmd_o,
                 command_instr_o.duration);

        if (command_valid_o != 1'b1)              $fatal(1, "Test 4 failed: command_valid expected");
        if (wait_cmd_o != 1'b1)                   $fatal(1, "Test 4 failed: wait_cmd expected");
        if (command_instr_o.opcode != OP_WAIT)    $fatal(1, "Test 4 failed: opcode mismatch");
        if (command_instr_o.duration != 12'd10)   $fatal(1, "Test 4 failed: duration mismatch");

        $display("WAIT command test PASSED");

        // --------------------------------------------------------
        // Test 5: RESET q3 should generate a reset command.
        // --------------------------------------------------------
        send_issue(make_instr(OP_RESET, 4'd3, 4'd0, 12'd3));

        $display("Test 5: RESET q3");
        $display("cmd_valid=%0b reset=%0b target=%0d",
                 command_valid_o, reset_cmd_o,
                 command_instr_o.target_qubit);

        if (command_valid_o != 1'b1)              $fatal(1, "Test 5 failed: command_valid expected");
        if (reset_cmd_o != 1'b1)                  $fatal(1, "Test 5 failed: reset_cmd expected");
        if (command_instr_o.opcode != OP_RESET)   $fatal(1, "Test 5 failed: opcode mismatch");
        if (command_instr_o.target_qubit != 4'd3) $fatal(1, "Test 5 failed: target mismatch");

        $display("RESET command test PASSED");

        // --------------------------------------------------------
        // Test 6: BRANCH should generate branch command.
        // --------------------------------------------------------
        send_issue(make_instr(OP_BRANCH, 4'd0, 4'd0, 12'd1));

        $display("Test 6: BRANCH");
        $display("cmd_valid=%0b branch=%0b opcode=%0h",
                 command_valid_o, branch_cmd_o,
                 command_instr_o.opcode);

        if (command_valid_o != 1'b1)              $fatal(1, "Test 6 failed: command_valid expected");
        if (branch_cmd_o != 1'b1)                 $fatal(1, "Test 6 failed: branch_cmd expected");
        if (command_instr_o.opcode != OP_BRANCH)  $fatal(1, "Test 6 failed: opcode mismatch");

        $display("BRANCH command test PASSED");

        // --------------------------------------------------------
        // Test 7: NOP should not generate command_valid, but should pulse nop_cmd.
        // --------------------------------------------------------
        send_issue(make_instr(OP_NOP, 4'd0, 4'd0, 12'd0));

        $display("Test 7: NOP");
        $display("cmd_valid=%0b nop=%0b opcode=%0h",
                 command_valid_o, nop_cmd_o,
                 command_instr_o.opcode);

        if (command_valid_o != 1'b0)           $fatal(1, "Test 7 failed: NOP should not assert command_valid");
        if (nop_cmd_o != 1'b1)                 $fatal(1, "Test 7 failed: nop_cmd expected");
        if (command_instr_o.opcode != OP_NOP)  $fatal(1, "Test 7 failed: opcode mismatch");

        $display("NOP command test PASSED");

        // --------------------------------------------------------
        // Test 8: OP_INVALID should raise illegal_issue_o.
        // --------------------------------------------------------
        send_issue(make_instr(OP_INVALID, 4'd0, 4'd0, 12'd0));

        $display("Test 8: Invalid issue");
        $display("cmd_valid=%0b illegal=%0b opcode=%0h",
                 command_valid_o, illegal_issue_o,
                 command_instr_o.opcode);

        if (command_valid_o != 1'b0)       $fatal(1, "Test 8 failed: invalid should not generate command_valid");
        if (illegal_issue_o != 1'b1)       $fatal(1, "Test 8 failed: illegal_issue expected");

        $display("Invalid issue test PASSED");

        $display("execution_controller test PASSED");
        $finish;
    end

endmodule
