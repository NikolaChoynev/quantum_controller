`timescale 1ns/1ps

import qc_pkg::*;

module tb_quantum_controller_top;

    logic                   clk_i;
    logic                   rst_ni;

    logic [INSTR_W-1:0]     instr_i;
    logic                   instr_valid_i;
    logic                   instr_ready_o;

    qc_opcode_e             opcode_o;
    logic [QUBIT_ID_W-1:0]  target_qubit_o;
    logic [QUBIT_ID_W-1:0]  control_qubit_o;
    logic [DURATION_W-1:0]  duration_o;
    logic [FLAGS_W-1:0]     flags_o;

    logic                   decoded_valid_o;
    logic                   illegal_instr_o;

    quantum_controller_top dut (
        .clk_i            (clk_i),
        .rst_ni           (rst_ni),
        .instr_i          (instr_i),
        .instr_valid_i    (instr_valid_i),
        .instr_ready_o    (instr_ready_o),
        .opcode_o         (opcode_o),
        .target_qubit_o   (target_qubit_o),
        .control_qubit_o  (control_qubit_o),
        .duration_o       (duration_o),
        .flags_o          (flags_o),
        .decoded_valid_o  (decoded_valid_o),
        .illegal_instr_o  (illegal_instr_o)
    );

    initial begin
        clk_i = 1'b0;
        forever #5 clk_i = ~clk_i;
    end

    task automatic send_instruction(input logic [INSTR_W-1:0] raw_instr);
        begin
            @(negedge clk_i);
            instr_i       = raw_instr;
            instr_valid_i = 1'b1;

            @(posedge clk_i);
            #1;

            instr_valid_i = 1'b0;
            instr_i       = '0;
        end
    endtask

    initial begin
        $dumpfile("results/waveforms/quantum_controller_top.vcd");
        $dumpvars(0, tb_quantum_controller_top);

        instr_i       = '0;
        instr_valid_i = 1'b0;
        rst_ni        = 1'b0;

        repeat (2) @(negedge clk_i);
        rst_ni = 1'b1;

        // --------------------------------------------------------
        // Test 1: H q2, duration 4
        // --------------------------------------------------------
        send_instruction({4'h1, 4'd2, 4'd0, 12'd4, 4'b1000, 4'd0});

        $display("Test 1: H q2");
        $display("opcode=%0h target=%0d control=%0d duration=%0d valid=%0b illegal=%0b",
                 opcode_o, target_qubit_o, control_qubit_o, duration_o,
                 decoded_valid_o, illegal_instr_o);

        if (opcode_o != OP_H)              $fatal(1, "Test 1 failed: opcode mismatch");
        if (target_qubit_o != 4'd2)        $fatal(1, "Test 1 failed: target mismatch");
        if (duration_o != 12'd4)           $fatal(1, "Test 1 failed: duration mismatch");
        if (decoded_valid_o != 1'b1)       $fatal(1, "Test 1 failed: decoded_valid mismatch");
        if (illegal_instr_o != 1'b0)       $fatal(1, "Test 1 failed: illegal mismatch");

        // --------------------------------------------------------
        // Test 2: CNOT q1, q3, duration 8
        // --------------------------------------------------------
        send_instruction({4'h4, 4'd1, 4'd3, 12'd8, 4'b1000, 4'd0});

        $display("Test 2: CNOT q1, q3");
        $display("opcode=%0h target=%0d control=%0d duration=%0d valid=%0b illegal=%0b",
                 opcode_o, target_qubit_o, control_qubit_o, duration_o,
                 decoded_valid_o, illegal_instr_o);

        if (opcode_o != OP_CNOT)           $fatal(1, "Test 2 failed: opcode mismatch");
        if (target_qubit_o != 4'd1)        $fatal(1, "Test 2 failed: target mismatch");
        if (control_qubit_o != 4'd3)       $fatal(1, "Test 2 failed: control mismatch");
        if (duration_o != 12'd8)           $fatal(1, "Test 2 failed: duration mismatch");
        if (decoded_valid_o != 1'b1)       $fatal(1, "Test 2 failed: decoded_valid mismatch");
        if (illegal_instr_o != 1'b0)       $fatal(1, "Test 2 failed: illegal mismatch");

        // --------------------------------------------------------
        // Test 3: Invalid opcode
        // --------------------------------------------------------
        send_instruction({4'hF, 4'd0, 4'd0, 12'd1, 4'b1000, 4'd0});

        $display("Test 3: Invalid opcode");
        $display("opcode=%0h target=%0d control=%0d duration=%0d valid=%0b illegal=%0b",
                 opcode_o, target_qubit_o, control_qubit_o, duration_o,
                 decoded_valid_o, illegal_instr_o);

        if (decoded_valid_o != 1'b0)       $fatal(1, "Test 3 failed: invalid instruction marked valid");
        if (illegal_instr_o != 1'b1)       $fatal(1, "Test 3 failed: invalid opcode not detected");

        $display("quantum_controller_top test PASSED");
        $finish;
    end

endmodule
