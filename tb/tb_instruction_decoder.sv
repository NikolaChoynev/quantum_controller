`timescale 1ns/1ps

import qc_pkg::*;

module tb_instruction_decoder;

    logic [INSTR_W-1:0]      instr_i;

    qc_opcode_e             opcode_o;
    logic [QUBIT_ID_W-1:0]  target_qubit_o;
    logic [QUBIT_ID_W-1:0]  control_qubit_o;
    logic [DURATION_W-1:0]  duration_o;
    logic [FLAGS_W-1:0]     flags_o;
    logic                   valid_o;
    logic                   illegal_o;

    instruction_decoder dut (
        .instr_i(instr_i),
        .opcode_o(opcode_o),
        .target_qubit_o(target_qubit_o),
        .control_qubit_o(control_qubit_o),
        .duration_o(duration_o),
        .flags_o(flags_o),
        .valid_o(valid_o),
        .illegal_o(illegal_o)
    );

    initial begin
        // --------------------------------------------------------
        // Test 1: H q2, duration 4, valid instruction
        // Format:
        // [31:28] opcode        = 4'h1 = OP_H
        // [27:24] target_qubit  = 2
        // [23:20] control_qubit = 0
        // [19:8]  duration      = 4
        // [7:4]   flags         = 4'b1000, valid = 1
        // [3:0]   reserved      = 0
        // --------------------------------------------------------
        instr_i = {4'h1, 4'd2, 4'd0, 12'd4, 4'b1000, 4'd0};
        #1;

        $display("Test 1: H q2");
        $display("opcode=%0h target=%0d control=%0d duration=%0d flags=%04b valid=%0b illegal=%0b",
                 opcode_o, target_qubit_o, control_qubit_o, duration_o, flags_o, valid_o, illegal_o);

        if (opcode_o != OP_H)              $fatal(1, "Test 1 failed: opcode mismatch");
        if (target_qubit_o != 4'd2)        $fatal(1, "Test 1 failed: target mismatch");
        if (control_qubit_o != 4'd0)       $fatal(1, "Test 1 failed: control mismatch");
        if (duration_o != 12'd4)           $fatal(1, "Test 1 failed: duration mismatch");
        if (valid_o != 1'b1)               $fatal(1, "Test 1 failed: valid mismatch");
        if (illegal_o != 1'b0)             $fatal(1, "Test 1 failed: illegal mismatch");

        // --------------------------------------------------------
        // Test 2: CNOT q1, q3, duration 8, valid instruction
        // --------------------------------------------------------
        instr_i = {4'h4, 4'd1, 4'd3, 12'd8, 4'b1000, 4'd0};
        #1;

        $display("Test 2: CNOT q1, q3");
        $display("opcode=%0h target=%0d control=%0d duration=%0d flags=%04b valid=%0b illegal=%0b",
                 opcode_o, target_qubit_o, control_qubit_o, duration_o, flags_o, valid_o, illegal_o);

        if (opcode_o != OP_CNOT)           $fatal(1, "Test 2 failed: opcode mismatch");
        if (target_qubit_o != 4'd1)        $fatal(1, "Test 2 failed: target mismatch");
        if (control_qubit_o != 4'd3)       $fatal(1, "Test 2 failed: control mismatch");
        if (duration_o != 12'd8)           $fatal(1, "Test 2 failed: duration mismatch");
        if (valid_o != 1'b1)               $fatal(1, "Test 2 failed: valid mismatch");
        if (illegal_o != 1'b0)             $fatal(1, "Test 2 failed: illegal mismatch");

        // --------------------------------------------------------
        // Test 3: Invalid opcode
        // --------------------------------------------------------
        instr_i = {4'hF, 4'd0, 4'd0, 12'd1, 4'b1000, 4'd0};
        #1;

        $display("Test 3: Invalid opcode");
        $display("opcode=%0h target=%0d control=%0d duration=%0d flags=%04b valid=%0b illegal=%0b",
                 opcode_o, target_qubit_o, control_qubit_o, duration_o, flags_o, valid_o, illegal_o);

        if (illegal_o != 1'b1)             $fatal(1, "Test 3 failed: invalid opcode not detected");

        $display("instruction_decoder test PASSED");
        $finish;
    end

endmodule
