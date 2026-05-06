`timescale 1ns/1ps

import qc_pkg::*;

module tb_quantum_controller_top;

    localparam int QUEUE_DEPTH = 4;

    logic                   clk_i;
    logic                   rst_ni;

    logic [INSTR_W-1:0]     instr_i;
    logic                   instr_valid_i;
    logic                   instr_ready_o;

    logic                   operation_pop_i;

    qc_opcode_e             opcode_o;
    logic [QUBIT_ID_W-1:0]  target_qubit_o;
    logic [QUBIT_ID_W-1:0]  control_qubit_o;
    logic [DURATION_W-1:0]  duration_o;
    logic [FLAGS_W-1:0]     flags_o;

    logic                   decoded_valid_o;
    logic                   illegal_instr_o;

    logic [$clog2(QUEUE_DEPTH+1)-1:0] queue_count_o;

    quantum_controller_top #(
        .QUEUE_DEPTH(QUEUE_DEPTH)
    ) dut (
        .clk_i            (clk_i),
        .rst_ni           (rst_ni),

        .instr_i          (instr_i),
        .instr_valid_i    (instr_valid_i),
        .instr_ready_o    (instr_ready_o),

        .operation_pop_i  (operation_pop_i),

        .opcode_o         (opcode_o),
        .target_qubit_o   (target_qubit_o),
        .control_qubit_o  (control_qubit_o),
        .duration_o       (duration_o),
        .flags_o          (flags_o),

        .decoded_valid_o  (decoded_valid_o),
        .illegal_instr_o  (illegal_instr_o),

        .queue_count_o    (queue_count_o)
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

    task automatic pop_operation();
        begin
            @(negedge clk_i);
            operation_pop_i = 1'b1;

            @(posedge clk_i);
            #1;

            operation_pop_i = 1'b0;
        end
    endtask

    initial begin
        $dumpfile("results/waveforms/quantum_controller_top.vcd");
        $dumpvars(0, tb_quantum_controller_top);

        instr_i         = '0;
        instr_valid_i   = 1'b0;
        operation_pop_i = 1'b0;
        rst_ni          = 1'b0;

        repeat (2) @(negedge clk_i);
        rst_ni = 1'b1;
        #1;

        if (decoded_valid_o != 1'b0) $fatal(1, "Top should not have valid decoded operation after reset");
        if (queue_count_o != 0)      $fatal(1, "Queue count should be 0 after reset");

        $display("Reset test PASSED");

        // --------------------------------------------------------
        // Test 1: Push H q2
        // --------------------------------------------------------
        send_instruction({4'h1, 4'd2, 4'd0, 12'd4, 4'b1000, 4'd0});

        $display("Test 1: Push H q2");
        $display("opcode=%0h target=%0d control=%0d duration=%0d valid=%0b illegal=%0b count=%0d",
                 opcode_o, target_qubit_o, control_qubit_o, duration_o,
                 decoded_valid_o, illegal_instr_o, queue_count_o);

        if (opcode_o != OP_H)              $fatal(1, "Test 1 failed: opcode mismatch");
        if (target_qubit_o != 4'd2)        $fatal(1, "Test 1 failed: target mismatch");
        if (duration_o != 12'd4)           $fatal(1, "Test 1 failed: duration mismatch");
        if (decoded_valid_o != 1'b1)       $fatal(1, "Test 1 failed: decoded_valid mismatch");
        if (queue_count_o != 1)            $fatal(1, "Test 1 failed: queue count mismatch");

        // --------------------------------------------------------
        // Test 2: Push CNOT q1, q3
        // FIFO head must still be H q2.
        // --------------------------------------------------------
        send_instruction({4'h4, 4'd1, 4'd3, 12'd8, 4'b1000, 4'd0});

        $display("Test 2: Push CNOT q1, q3");
        $display("head opcode=%0h target=%0d control=%0d duration=%0d valid=%0b count=%0d",
                 opcode_o, target_qubit_o, control_qubit_o, duration_o,
                 decoded_valid_o, queue_count_o);

        if (queue_count_o != 2)            $fatal(1, "Test 2 failed: queue count mismatch");
        if (opcode_o != OP_H)              $fatal(1, "Test 2 failed: FIFO order broken");

        // --------------------------------------------------------
        // Test 3: Pop H q2.
        // Head must become CNOT q1, q3.
        // --------------------------------------------------------
        pop_operation();

        $display("Test 3: Pop H q2");
        $display("head opcode=%0h target=%0d control=%0d duration=%0d valid=%0b count=%0d",
                 opcode_o, target_qubit_o, control_qubit_o, duration_o,
                 decoded_valid_o, queue_count_o);

        if (queue_count_o != 1)            $fatal(1, "Test 3 failed: queue count mismatch");
        if (opcode_o != OP_CNOT)           $fatal(1, "Test 3 failed: opcode should be OP_CNOT");
        if (target_qubit_o != 4'd1)        $fatal(1, "Test 3 failed: target mismatch");
        if (control_qubit_o != 4'd3)       $fatal(1, "Test 3 failed: control mismatch");

        // --------------------------------------------------------
        // Test 4: Pop CNOT q1, q3.
        // Queue must become empty.
        // --------------------------------------------------------
        pop_operation();

        $display("Test 4: Pop CNOT q1, q3");
        $display("valid=%0b count=%0d", decoded_valid_o, queue_count_o);

        if (decoded_valid_o != 1'b0)       $fatal(1, "Test 4 failed: queue should be empty");
        if (queue_count_o != 0)            $fatal(1, "Test 4 failed: queue count should be 0");

        // --------------------------------------------------------
        // Test 5: Invalid opcode.
        // It should not enter the queue.
        // --------------------------------------------------------
        send_instruction({4'hF, 4'd0, 4'd0, 12'd1, 4'b1000, 4'd0});

        $display("Test 5: Invalid opcode");
        $display("valid=%0b illegal=%0b count=%0d",
                 decoded_valid_o, illegal_instr_o, queue_count_o);

        if (illegal_instr_o != 1'b1)       $fatal(1, "Test 5 failed: invalid opcode not detected");
        if (queue_count_o != 0)            $fatal(1, "Test 5 failed: invalid instruction entered queue");

        $display("quantum_controller_top integrated queue test PASSED");
        $finish;
    end

endmodule
