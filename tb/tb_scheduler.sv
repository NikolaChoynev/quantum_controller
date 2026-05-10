`timescale 1ns/1ps

import qc_pkg::*;

module tb_scheduler;

    localparam int NUM_QUBITS = 16;

    logic clk_i;
    logic rst_ni;

    logic instr_valid_i;
    qc_instr_fields_t instr_i;
    logic issue_ready_i;

    logic queue_pop_o;

    logic issue_valid_o;
    qc_instr_fields_t issue_instr_o;

    logic stall_o;
    logic [NUM_QUBITS-1:0] qubit_busy_o;

    scheduler #(
        .NUM_QUBITS(NUM_QUBITS)
    ) dut (
        .clk_i         (clk_i),
        .rst_ni        (rst_ni),

        .instr_valid_i (instr_valid_i),
        .instr_i       (instr_i),
        .issue_ready_i (issue_ready_i),

        .queue_pop_o   (queue_pop_o),

        .issue_valid_o (issue_valid_o),
        .issue_instr_o (issue_instr_o),

        .stall_o       (stall_o),
        .qubit_busy_o  (qubit_busy_o)
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

    task automatic present_instr(input qc_instr_fields_t instr);
        begin
            @(negedge clk_i);
            instr_i       = instr;
            instr_valid_i = 1'b1;
            #1;
        end
    endtask

    task automatic clear_instr();
        begin
            @(negedge clk_i);
            instr_i       = '0;
            instr_valid_i = 1'b0;
            #1;
        end
    endtask

    task automatic issue_cycle();
        begin
            @(posedge clk_i);
            #1;
        end
    endtask

    initial begin
        $dumpfile("results/waveforms/scheduler.vcd");
        $dumpvars(0, tb_scheduler);

        instr_valid_i = 1'b0;
        instr_i       = '0;
        issue_ready_i = 1'b1;
        rst_ni        = 1'b0;

        repeat (2) @(negedge clk_i);
        rst_ni = 1'b1;
        #1;

        if (issue_valid_o != 1'b0) $fatal(1, "Issue valid should be 0 after reset");
        if (stall_o != 1'b0)       $fatal(1, "Stall should be 0 after reset");

        $display("Reset test PASSED");

        // --------------------------------------------------------
        // Test 1: Issue H q0
        // --------------------------------------------------------
        present_instr(make_instr(OP_H, 4'd0, 4'd0, 12'd2));

        if (queue_pop_o != 1'b1) $fatal(1, "Test 1 failed: scheduler should pop H q0");
        if (stall_o != 1'b0)     $fatal(1, "Test 1 failed: scheduler should not stall H q0");

        issue_cycle();

        if (issue_valid_o != 1'b1)       $fatal(1, "Test 1 failed: H q0 not issued");
        if (issue_instr_o.opcode != OP_H) $fatal(1, "Test 1 failed: issued opcode mismatch");
        if (qubit_busy_o[0] != 1'b1)     $fatal(1, "Test 1 failed: q0 should be busy");

        $display("Issue H q0 test PASSED");

        // --------------------------------------------------------
        // Test 2: Issue X q1 while q0 is busy.
        // This should be allowed because q1 is independent.
        // --------------------------------------------------------
        present_instr(make_instr(OP_X, 4'd1, 4'd0, 12'd2));

        if (queue_pop_o != 1'b1) $fatal(1, "Test 2 failed: X q1 should be schedulable");
        if (stall_o != 1'b0)     $fatal(1, "Test 2 failed: X q1 should not stall");

        issue_cycle();

        if (issue_valid_o != 1'b1)        $fatal(1, "Test 2 failed: X q1 not issued");
        if (issue_instr_o.opcode != OP_X) $fatal(1, "Test 2 failed: issued opcode mismatch");
        if (qubit_busy_o[1] != 1'b1)      $fatal(1, "Test 2 failed: q1 should be busy");

        $display("Independent X q1 test PASSED");

        clear_instr();

        repeat (3) begin
            @(posedge clk_i);
            #1;
        end

        if (qubit_busy_o[0] != 1'b0) $fatal(1, "q0 should be free");
        if (qubit_busy_o[1] != 1'b0) $fatal(1, "q1 should be free");

        $display("Busy counter clear test PASSED");

        // --------------------------------------------------------
        // Test 3: Hazard detection.
        // First issue H q0. Then try CNOT q1, q0 while q0 is busy.
        // Scheduler must stall.
        // --------------------------------------------------------
        present_instr(make_instr(OP_H, 4'd0, 4'd0, 12'd2));

        if (queue_pop_o != 1'b1) $fatal(1, "Test 3 setup failed: H q0 should issue");

        issue_cycle();

        if (issue_valid_o != 1'b1) $fatal(1, "Test 3 setup failed: H q0 not issued");

        present_instr(make_instr(OP_CNOT, 4'd1, 4'd0, 12'd3));

        if (queue_pop_o != 1'b0) $fatal(1, "Test 3 failed: CNOT should not pop while q0 busy");
        if (stall_o != 1'b1)     $fatal(1, "Test 3 failed: CNOT should stall while q0 busy");

        issue_cycle();

        if (issue_valid_o != 1'b0) $fatal(1, "Test 3 failed: CNOT issued despite hazard");

        $display("CNOT dependency hazard test PASSED");

        clear_instr();

        repeat (2) begin
            @(posedge clk_i);
            #1;
        end

        // --------------------------------------------------------
        // Test 4: CNOT after q0 becomes free.
        // --------------------------------------------------------
        present_instr(make_instr(OP_CNOT, 4'd1, 4'd0, 12'd3));

        if (queue_pop_o != 1'b1) $fatal(1, "Test 4 failed: CNOT should pop after q0 is free");
        if (stall_o != 1'b0)     $fatal(1, "Test 4 failed: CNOT should not stall after q0 is free");

        issue_cycle();

        if (issue_valid_o != 1'b1)             $fatal(1, "Test 4 failed: CNOT not issued");
        if (issue_instr_o.opcode != OP_CNOT)   $fatal(1, "Test 4 failed: issued opcode mismatch");
        if (qubit_busy_o[0] != 1'b1)           $fatal(1, "Test 4 failed: control q0 should be busy");
        if (qubit_busy_o[1] != 1'b1)           $fatal(1, "Test 4 failed: target q1 should be busy");

        $display("CNOT issue after dependency clears test PASSED");

        clear_instr();

        repeat (4) begin
            @(posedge clk_i);
            #1;
        end

        // --------------------------------------------------------
        // Test 5: Downstream backpressure.
        // Scheduler must hold the queue head while issue_ready_i=0.
        // --------------------------------------------------------
        issue_ready_i = 1'b0;
        present_instr(make_instr(OP_H, 4'd2, 4'd0, 12'd1));

        if (queue_pop_o != 1'b0) $fatal(1, "Test 5 failed: scheduler popped while downstream not ready");
        if (stall_o != 1'b1)     $fatal(1, "Test 5 failed: scheduler should stall on backpressure");

        issue_cycle();

        if (issue_valid_o != 1'b0) $fatal(1, "Test 5 failed: scheduler issued while downstream not ready");

        @(negedge clk_i);
        issue_ready_i = 1'b1;
        #1;

        if (queue_pop_o != 1'b1) $fatal(1, "Test 5 failed: scheduler did not pop after ready");

        issue_cycle();

        if (issue_valid_o != 1'b1)       $fatal(1, "Test 5 failed: H q2 not issued after ready");
        if (issue_instr_o.opcode != OP_H) $fatal(1, "Test 5 failed: issued opcode mismatch");

        $display("Backpressure stall test PASSED");

        clear_instr();

        repeat (2) begin
            @(posedge clk_i);
            #1;
        end

        // --------------------------------------------------------
        // Test 6: WAIT creates a global scheduler hold.
        // --------------------------------------------------------
        present_instr(make_instr(OP_WAIT, 4'd0, 4'd0, 12'd3));

        if (queue_pop_o != 1'b1) $fatal(1, "Test 6 failed: WAIT should pop");

        issue_cycle();

        if (issue_valid_o != 1'b1)          $fatal(1, "Test 6 failed: WAIT not issued");
        if (issue_instr_o.opcode != OP_WAIT) $fatal(1, "Test 6 failed: issued opcode mismatch");

        present_instr(make_instr(OP_H, 4'd3, 4'd0, 12'd1));

        if (queue_pop_o != 1'b0) $fatal(1, "Test 6 failed: H should not pop while WAIT active");
        if (stall_o != 1'b1)     $fatal(1, "Test 6 failed: WAIT should stall following instruction");

        repeat (3) begin
            issue_cycle();
        end

        if (queue_pop_o != 1'b1) $fatal(1, "Test 6 failed: H should pop after WAIT expires");

        issue_cycle();

        if (issue_valid_o != 1'b1)       $fatal(1, "Test 6 failed: H q3 not issued after WAIT");
        if (issue_instr_o.opcode != OP_H) $fatal(1, "Test 6 failed: issued opcode mismatch after WAIT");

        $display("WAIT scheduler hold test PASSED");

        $display("scheduler test PASSED");
        $finish;
    end

endmodule
