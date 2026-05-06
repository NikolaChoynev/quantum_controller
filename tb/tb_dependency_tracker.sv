`timescale 1ns/1ps

import qc_pkg::*;

module tb_dependency_tracker;

    localparam int NUM_QUBITS = 16;

    logic instr_valid_i;
    qc_instr_fields_t instr_i;

    logic [NUM_QUBITS-1:0] qubit_busy_i;

    logic uses_target_o;
    logic uses_control_o;

    logic [NUM_QUBITS-1:0] qubit_mask_o;

    logic target_busy_o;
    logic control_busy_o;

    logic dependency_hazard_o;
    logic independent_o;

    dependency_tracker #(
        .NUM_QUBITS(NUM_QUBITS)
    ) dut (
        .instr_valid_i       (instr_valid_i),
        .instr_i             (instr_i),

        .qubit_busy_i        (qubit_busy_i),

        .uses_target_o       (uses_target_o),
        .uses_control_o      (uses_control_o),

        .qubit_mask_o        (qubit_mask_o),

        .target_busy_o       (target_busy_o),
        .control_busy_o      (control_busy_o),

        .dependency_hazard_o (dependency_hazard_o),
        .independent_o       (independent_o)
    );

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

    initial begin
        $dumpfile("results/waveforms/dependency_tracker.vcd");
        $dumpvars(0, tb_dependency_tracker);

        instr_valid_i = 1'b0;
        instr_i       = '0;
        qubit_busy_i  = '0;
        #1;

        if (dependency_hazard_o != 1'b0) $fatal(1, "Invalid input should not create hazard");
        if (independent_o != 1'b0)       $fatal(1, "Invalid input should not be marked independent");

        $display("Reset-like invalid input test PASSED");

        // --------------------------------------------------------
        // Test 1: H q0 with q0 free.
        // Expected: target used, no hazard.
        // --------------------------------------------------------
        instr_valid_i = 1'b1;
        instr_i       = make_instr(OP_H, 4'd0, 4'd0, 12'd4);
        qubit_busy_i  = '0;
        #1;

        $display("Test 1: H q0, q0 free");
        $display("mask=%016b uses_t=%0b uses_c=%0b t_busy=%0b c_busy=%0b hazard=%0b independent=%0b",
                 qubit_mask_o, uses_target_o, uses_control_o,
                 target_busy_o, control_busy_o,
                 dependency_hazard_o, independent_o);

        if (uses_target_o != 1'b1)             $fatal(1, "Test 1 failed: target should be used");
        if (uses_control_o != 1'b0)            $fatal(1, "Test 1 failed: control should not be used");
        if (qubit_mask_o[0] != 1'b1)           $fatal(1, "Test 1 failed: q0 should be in mask");
        if (dependency_hazard_o != 1'b0)       $fatal(1, "Test 1 failed: no hazard expected");
        if (independent_o != 1'b1)             $fatal(1, "Test 1 failed: instruction should be independent");

        $display("H q0 free test PASSED");

        // --------------------------------------------------------
        // Test 2: H q0 with q0 busy.
        // Expected: dependency hazard.
        // --------------------------------------------------------
        instr_valid_i = 1'b1;
        instr_i       = make_instr(OP_H, 4'd0, 4'd0, 12'd4);
        qubit_busy_i  = '0;
        qubit_busy_i[0] = 1'b1;
        #1;

        $display("Test 2: H q0, q0 busy");
        $display("mask=%016b t_busy=%0b hazard=%0b independent=%0b",
                 qubit_mask_o, target_busy_o,
                 dependency_hazard_o, independent_o);

        if (target_busy_o != 1'b1)             $fatal(1, "Test 2 failed: target should be busy");
        if (dependency_hazard_o != 1'b1)       $fatal(1, "Test 2 failed: hazard expected");
        if (independent_o != 1'b0)             $fatal(1, "Test 2 failed: instruction should not be independent");

        $display("H q0 busy hazard test PASSED");

        // --------------------------------------------------------
        // Test 3: CNOT q1, q3 with control q3 busy.
        // Expected: control dependency hazard.
        // --------------------------------------------------------
        instr_valid_i = 1'b1;
        instr_i       = make_instr(OP_CNOT, 4'd1, 4'd3, 12'd8);
        qubit_busy_i  = '0;
        qubit_busy_i[3] = 1'b1;
        #1;

        $display("Test 3: CNOT q1, q3, q3 busy");
        $display("mask=%016b uses_t=%0b uses_c=%0b t_busy=%0b c_busy=%0b hazard=%0b",
                 qubit_mask_o, uses_target_o, uses_control_o,
                 target_busy_o, control_busy_o,
                 dependency_hazard_o);

        if (uses_target_o != 1'b1)             $fatal(1, "Test 3 failed: target should be used");
        if (uses_control_o != 1'b1)            $fatal(1, "Test 3 failed: control should be used");
        if (qubit_mask_o[1] != 1'b1)           $fatal(1, "Test 3 failed: q1 should be in mask");
        if (qubit_mask_o[3] != 1'b1)           $fatal(1, "Test 3 failed: q3 should be in mask");
        if (target_busy_o != 1'b0)             $fatal(1, "Test 3 failed: target should be free");
        if (control_busy_o != 1'b1)            $fatal(1, "Test 3 failed: control should be busy");
        if (dependency_hazard_o != 1'b1)       $fatal(1, "Test 3 failed: hazard expected");

        $display("CNOT control hazard test PASSED");

        // --------------------------------------------------------
        // Test 4: CNOT q1, q3 with both qubits free.
        // Expected: no hazard.
        // --------------------------------------------------------
        instr_valid_i = 1'b1;
        instr_i       = make_instr(OP_CNOT, 4'd1, 4'd3, 12'd8);
        qubit_busy_i  = '0;
        #1;

        $display("Test 4: CNOT q1, q3, both free");
        $display("mask=%016b hazard=%0b independent=%0b",
                 qubit_mask_o, dependency_hazard_o, independent_o);

        if (dependency_hazard_o != 1'b0)       $fatal(1, "Test 4 failed: no hazard expected");
        if (independent_o != 1'b1)             $fatal(1, "Test 4 failed: instruction should be independent");

        $display("CNOT free test PASSED");

        // --------------------------------------------------------
        // Test 5: X q2 while q0 and q1 are busy.
        // Expected: no hazard, because q2 is free.
        // --------------------------------------------------------
        instr_valid_i = 1'b1;
        instr_i       = make_instr(OP_X, 4'd2, 4'd0, 12'd4);
        qubit_busy_i  = '0;
        qubit_busy_i[0] = 1'b1;
        qubit_busy_i[1] = 1'b1;
        #1;

        $display("Test 5: X q2 while q0/q1 busy");
        $display("mask=%016b t_busy=%0b hazard=%0b independent=%0b",
                 qubit_mask_o, target_busy_o,
                 dependency_hazard_o, independent_o);

        if (qubit_mask_o[2] != 1'b1)           $fatal(1, "Test 5 failed: q2 should be in mask");
        if (target_busy_o != 1'b0)             $fatal(1, "Test 5 failed: q2 should be free");
        if (dependency_hazard_o != 1'b0)       $fatal(1, "Test 5 failed: no hazard expected");
        if (independent_o != 1'b1)             $fatal(1, "Test 5 failed: instruction should be independent");

        $display("Independent X q2 test PASSED");

        // --------------------------------------------------------
        // Test 6: NOP should not use any qubit.
        // Expected: no mask, no hazard.
        // --------------------------------------------------------
        instr_valid_i = 1'b1;
        instr_i       = make_instr(OP_NOP, 4'd0, 4'd0, 12'd0);
        qubit_busy_i  = '1;
        #1;

        $display("Test 6: NOP");
        $display("mask=%016b uses_t=%0b uses_c=%0b hazard=%0b",
                 qubit_mask_o, uses_target_o, uses_control_o,
                 dependency_hazard_o);

        if (uses_target_o != 1'b0)             $fatal(1, "Test 6 failed: NOP should not use target");
        if (uses_control_o != 1'b0)            $fatal(1, "Test 6 failed: NOP should not use control");
        if (qubit_mask_o != '0)                $fatal(1, "Test 6 failed: NOP mask should be zero");
        if (dependency_hazard_o != 1'b0)       $fatal(1, "Test 6 failed: NOP should not create hazard");

        $display("NOP test PASSED");

        $display("dependency_tracker test PASSED");
        $finish;
    end

endmodule
