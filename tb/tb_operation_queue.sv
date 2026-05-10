`timescale 1ns/1ps

import qc_pkg::*;

module tb_operation_queue;

    logic clk_i;
    logic rst_ni;

    logic push_i;
    qc_instr_fields_t instr_i;
    logic full_o;

    logic flush_i;
    logic pop_i;
    qc_instr_fields_t instr_o;
    logic empty_o;

    logic [$clog2(4+1)-1:0] count_o;

    operation_queue #(
        .DEPTH(4)
    ) dut (
        .clk_i   (clk_i),
        .rst_ni  (rst_ni),

        .push_i  (push_i),
        .instr_i (instr_i),
        .full_o  (full_o),

        .flush_i (flush_i),

        .pop_i   (pop_i),
        .instr_o (instr_o),
        .empty_o (empty_o),

        .count_o (count_o)
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

    task automatic push_instr(input qc_instr_fields_t instr);
        begin
            @(negedge clk_i);
            instr_i = instr;
            push_i  = 1'b1;

            @(posedge clk_i);
            #1;

            push_i  = 1'b0;
            instr_i = '0;
        end
    endtask

    task automatic pop_instr();
        begin
            @(negedge clk_i);
            pop_i = 1'b1;

            @(posedge clk_i);
            #1;

            pop_i = 1'b0;
        end
    endtask

    task automatic flush_queue();
        begin
            @(negedge clk_i);
            flush_i = 1'b1;

            @(posedge clk_i);
            #1;

            flush_i = 1'b0;
        end
    endtask

    initial begin
        $dumpfile("results/waveforms/operation_queue.vcd");
        $dumpvars(0, tb_operation_queue);

        push_i  = 1'b0;
        flush_i = 1'b0;
        pop_i   = 1'b0;
        instr_i = '0;
        rst_ni  = 1'b0;

        repeat (2) @(negedge clk_i);
        rst_ni = 1'b1;
        #1;

        if (empty_o != 1'b1) $fatal(1, "Queue should be empty after reset");
        if (full_o  != 1'b0) $fatal(1, "Queue should not be full after reset");
        if (count_o != 0)    $fatal(1, "Queue count should be 0 after reset");

        $display("Reset test PASSED");

        push_instr(make_instr(OP_H, 4'd0, 4'd0, 12'd4));

        if (empty_o != 1'b0)              $fatal(1, "Queue should not be empty after push");
        if (count_o != 1)                 $fatal(1, "Queue count should be 1");
        if (instr_o.opcode != OP_H)       $fatal(1, "Head opcode should be OP_H");
        if (instr_o.target_qubit != 4'd0) $fatal(1, "Head target should be q0");

        $display("Push H q0 test PASSED");

        push_instr(make_instr(OP_CNOT, 4'd1, 4'd3, 12'd8));

        if (count_o != 2)                 $fatal(1, "Queue count should be 2");
        if (instr_o.opcode != OP_H)       $fatal(1, "Queue should preserve FIFO order");

        $display("Push CNOT q1 q3 test PASSED");

        pop_instr();

        if (count_o != 1)                    $fatal(1, "Queue count should be 1 after pop");
        if (instr_o.opcode != OP_CNOT)       $fatal(1, "Head opcode should be OP_CNOT after pop");
        if (instr_o.target_qubit != 4'd1)    $fatal(1, "CNOT target should be q1");
        if (instr_o.control_qubit != 4'd3)   $fatal(1, "CNOT control should be q3");

        $display("Pop H q0 test PASSED");

        pop_instr();

        if (empty_o != 1'b1) $fatal(1, "Queue should be empty after second pop");
        if (count_o != 0)    $fatal(1, "Queue count should be 0 after second pop");

        $display("Pop CNOT q1 q3 test PASSED");

        push_instr(make_instr(OP_H,       4'd0, 4'd0, 12'd4));
        push_instr(make_instr(OP_X,       4'd1, 4'd0, 12'd4));
        push_instr(make_instr(OP_Z,       4'd2, 4'd0, 12'd4));
        push_instr(make_instr(OP_MEASURE, 4'd3, 4'd0, 12'd8));

        if (full_o != 1'b1) $fatal(1, "Queue should be full");
        if (count_o != 4)   $fatal(1, "Queue count should be 4 when full");

        $display("Full queue test PASSED");

        flush_queue();

        if (empty_o != 1'b1) $fatal(1, "Queue should be empty after flush");
        if (full_o  != 1'b0) $fatal(1, "Queue should not be full after flush");
        if (count_o != 0)    $fatal(1, "Queue count should be 0 after flush");

        $display("Flush queue test PASSED");

        $display("operation_queue test PASSED");
        $finish;
    end

endmodule
