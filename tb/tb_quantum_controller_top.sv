`timescale 1ns/1ps

import qc_pkg::*;

module tb_quantum_controller_top;

    localparam int QUEUE_DEPTH = 4;
    localparam int NUM_QUBITS  = 16;

    logic                   clk_i;
    logic                   rst_ni;

    logic [INSTR_W-1:0]     instr_i;
    logic                   instr_valid_i;
    logic                   instr_ready_o;

    logic                   issue_valid_o;
    qc_opcode_e             issue_opcode_o;
    logic [QUBIT_ID_W-1:0]  issue_target_qubit_o;
    logic [QUBIT_ID_W-1:0]  issue_control_qubit_o;
    logic [DURATION_W-1:0]  issue_duration_o;
    logic [FLAGS_W-1:0]     issue_flags_o;

    logic                   scheduler_stall_o;
    logic                   illegal_instr_o;

    logic [$clog2(QUEUE_DEPTH+1)-1:0] queue_count_o;
    logic [NUM_QUBITS-1:0]             qubit_busy_o;

    quantum_controller_top #(
        .QUEUE_DEPTH(QUEUE_DEPTH),
        .NUM_QUBITS(NUM_QUBITS)
    ) dut (
        .clk_i                 (clk_i),
        .rst_ni                (rst_ni),

        .instr_i               (instr_i),
        .instr_valid_i         (instr_valid_i),
        .instr_ready_o         (instr_ready_o),

        .issue_valid_o         (issue_valid_o),
        .issue_opcode_o        (issue_opcode_o),
        .issue_target_qubit_o  (issue_target_qubit_o),
        .issue_control_qubit_o (issue_control_qubit_o),
        .issue_duration_o      (issue_duration_o),
        .issue_flags_o         (issue_flags_o),

        .scheduler_stall_o     (scheduler_stall_o),
        .illegal_instr_o       (illegal_instr_o),

        .queue_count_o         (queue_count_o),
        .qubit_busy_o          (qubit_busy_o)
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

    task automatic wait_for_issue();
        begin
            while (issue_valid_o != 1'b1) begin
                @(posedge clk_i);
                #1;
            end
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
        #1;

        if (queue_count_o != 0)      $fatal(1, "Queue count should be 0 after reset");
        if (issue_valid_o != 1'b0)   $fatal(1, "Issue valid should be 0 after reset");

        $display("Reset test PASSED");

        // --------------------------------------------------------
        // Test 1: H q0 enters queue and then gets issued.
        // --------------------------------------------------------
        send_instruction({4'h1, 4'd0, 4'd0, 12'd4, 4'b1000, 4'd0});

        if (queue_count_o != 1) $fatal(1, "Test 1 failed: instruction should be queued");

        wait_for_issue();

        $display("Test 1: Issue H q0");
        $display("issue_valid=%0b opcode=%0h target=%0d duration=%0d busy_q0=%0b count=%0d",
                 issue_valid_o, issue_opcode_o, issue_target_qubit_o,
                 issue_duration_o, qubit_busy_o[0], queue_count_o);

        if (issue_opcode_o != OP_H)          $fatal(1, "Test 1 failed: issued opcode mismatch");
        if (issue_target_qubit_o != 4'd0)    $fatal(1, "Test 1 failed: target mismatch");
        if (issue_duration_o != 12'd4)       $fatal(1, "Test 1 failed: duration mismatch");
        if (qubit_busy_o[0] != 1'b1)         $fatal(1, "Test 1 failed: q0 should be busy");

        // --------------------------------------------------------
        // Test 2: X q1 should issue while q0 is busy.
        // This validates independent operation scheduling.
        // --------------------------------------------------------
        send_instruction({4'h2, 4'd1, 4'd0, 12'd2, 4'b1000, 4'd0});

        if (scheduler_stall_o != 1'b0) $fatal(1, "Test 2 failed: X q1 should not stall");

        wait_for_issue();

        $display("Test 2: Issue independent X q1");
        $display("issue_valid=%0b opcode=%0h target=%0d busy_q0=%0b busy_q1=%0b",
                 issue_valid_o, issue_opcode_o, issue_target_qubit_o,
                 qubit_busy_o[0], qubit_busy_o[1]);

        if (issue_opcode_o != OP_X)          $fatal(1, "Test 2 failed: issued opcode mismatch");
        if (issue_target_qubit_o != 4'd1)    $fatal(1, "Test 2 failed: target mismatch");
        if (qubit_busy_o[1] != 1'b1)         $fatal(1, "Test 2 failed: q1 should be busy");

        // --------------------------------------------------------
        // Test 3: CNOT q2, q0 should stall while q0 is busy.
        // --------------------------------------------------------
        send_instruction({4'h4, 4'd2, 4'd0, 12'd3, 4'b1000, 4'd0});

        $display("Test 3: CNOT q2, q0 while q0 may be busy");
        $display("stall=%0b count=%0d busy_q0=%0b",
                 scheduler_stall_o, queue_count_o, qubit_busy_o[0]);

        if (qubit_busy_o[0] == 1'b1) begin
            if (scheduler_stall_o != 1'b1) $fatal(1, "Test 3 failed: CNOT should stall while q0 is busy");
        end

        wait_for_issue();

        $display("Test 3: Issue CNOT q2, q0 after dependency clears");
        $display("issue_valid=%0b opcode=%0h target=%0d control=%0d",
                 issue_valid_o, issue_opcode_o,
                 issue_target_qubit_o, issue_control_qubit_o);

        if (issue_opcode_o != OP_CNOT)          $fatal(1, "Test 3 failed: issued opcode mismatch");
        if (issue_target_qubit_o != 4'd2)       $fatal(1, "Test 3 failed: target mismatch");
        if (issue_control_qubit_o != 4'd0)      $fatal(1, "Test 3 failed: control mismatch");

        // --------------------------------------------------------
        // Test 4: Invalid opcode should not enter the queue.
        // --------------------------------------------------------
        send_instruction({4'hF, 4'd0, 4'd0, 12'd1, 4'b1000, 4'd0});

        $display("Test 4: Invalid opcode");
        $display("illegal=%0b count=%0d", illegal_instr_o, queue_count_o);

        if (illegal_instr_o != 1'b1) $fatal(1, "Test 4 failed: invalid opcode not detected");

        $display("quantum_controller_top scheduler integration test PASSED");
        $finish;
    end

endmodule
