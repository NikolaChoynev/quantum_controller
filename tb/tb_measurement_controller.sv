`timescale 1ns/1ps

import qc_pkg::*;

module tb_measurement_controller;

    localparam int NUM_QUBITS = 16;

    logic clk_i;
    logic rst_ni;

    logic command_valid_i;
    qc_instr_fields_t command_instr_i;
    logic command_ready_o;

    logic measurement_result_valid_i;
    logic measurement_result_i;

    logic measure_request_valid_o;
    logic [QUBIT_ID_W-1:0] measure_qubit_o;

    logic measurement_busy_o;

    logic result_valid_o;
    logic [QUBIT_ID_W-1:0] result_qubit_o;
    logic result_value_o;

    logic [NUM_QUBITS-1:0] measurement_valid_o;
    logic [NUM_QUBITS-1:0] measurement_results_o;

    logic unexpected_result_o;

    measurement_controller #(
        .NUM_QUBITS(NUM_QUBITS)
    ) dut (
        .clk_i                      (clk_i),
        .rst_ni                     (rst_ni),

        .command_valid_i            (command_valid_i),
        .command_instr_i            (command_instr_i),
        .command_ready_o            (command_ready_o),

        .measurement_result_valid_i (measurement_result_valid_i),
        .measurement_result_i       (measurement_result_i),

        .measure_request_valid_o    (measure_request_valid_o),
        .measure_qubit_o            (measure_qubit_o),

        .measurement_busy_o         (measurement_busy_o),

        .result_valid_o             (result_valid_o),
        .result_qubit_o             (result_qubit_o),
        .result_value_o             (result_value_o),

        .measurement_valid_o        (measurement_valid_o),
        .measurement_results_o      (measurement_results_o),

        .unexpected_result_o        (unexpected_result_o)
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

    task automatic send_command(input qc_instr_fields_t instr);
        begin
            @(negedge clk_i);
            command_instr_i = instr;
            command_valid_i = 1'b1;

            @(posedge clk_i);
            #1;

            command_valid_i = 1'b0;
            command_instr_i = '0;
        end
    endtask

    task automatic send_measurement_result(input logic value);
        begin
            @(negedge clk_i);
            measurement_result_i       = value;
            measurement_result_valid_i = 1'b1;

            @(posedge clk_i);
            #1;

            measurement_result_valid_i = 1'b0;
            measurement_result_i       = 1'b0;
        end
    endtask

    initial begin
        $dumpfile("results/waveforms/measurement_controller.vcd");
        $dumpvars(0, tb_measurement_controller);

        command_valid_i            = 1'b0;
        command_instr_i            = '0;
        measurement_result_valid_i = 1'b0;
        measurement_result_i       = 1'b0;
        rst_ni                     = 1'b0;

        repeat (2) @(negedge clk_i);
        rst_ni = 1'b1;
        #1;

        if (command_ready_o != 1'b1)        $fatal(1, "Controller should be ready after reset");
        if (measurement_busy_o != 1'b0)     $fatal(1, "Controller should not be busy after reset");
        if (measurement_valid_o != '0)      $fatal(1, "No measurement should be valid after reset");
        if (unexpected_result_o != 1'b0)    $fatal(1, "Unexpected result should be 0 after reset");

        $display("Reset test PASSED");

        // --------------------------------------------------------
        // Test 1: MEASURE q2 creates request and enters busy state.
        // --------------------------------------------------------
        send_command(make_instr(OP_MEASURE, 4'd2, 4'd0, 12'd6));

        $display("Test 1: MEASURE q2 request");
        $display("request=%0b qubit=%0d busy=%0b ready=%0b",
                 measure_request_valid_o,
                 measure_qubit_o,
                 measurement_busy_o,
                 command_ready_o);

        if (measure_request_valid_o != 1'b1) $fatal(1, "Test 1 failed: measure request expected");
        if (measure_qubit_o != 4'd2)         $fatal(1, "Test 1 failed: measure qubit mismatch");
        if (measurement_busy_o != 1'b1)      $fatal(1, "Test 1 failed: controller should be busy");
        if (command_ready_o != 1'b0)         $fatal(1, "Test 1 failed: controller should not be ready while busy");

        $display("MEASURE request test PASSED");

        // --------------------------------------------------------
        // Test 2: Result for q2 is stored.
        // --------------------------------------------------------
        send_measurement_result(1'b1);

        $display("Test 2: Measurement result q2 = 1");
        $display("result_valid=%0b qubit=%0d value=%0b stored_valid=%0b stored_value=%0b busy=%0b",
                 result_valid_o,
                 result_qubit_o,
                 result_value_o,
                 measurement_valid_o[2],
                 measurement_results_o[2],
                 measurement_busy_o);

        if (result_valid_o != 1'b1)          $fatal(1, "Test 2 failed: result_valid expected");
        if (result_qubit_o != 4'd2)          $fatal(1, "Test 2 failed: result qubit mismatch");
        if (result_value_o != 1'b1)          $fatal(1, "Test 2 failed: result value mismatch");
        if (measurement_valid_o[2] != 1'b1)  $fatal(1, "Test 2 failed: stored valid missing");
        if (measurement_results_o[2] != 1'b1)$fatal(1, "Test 2 failed: stored value mismatch");
        if (measurement_busy_o != 1'b0)      $fatal(1, "Test 2 failed: controller should be free");

        $display("Measurement result storage test PASSED");

        // --------------------------------------------------------
        // Test 3: MEASURE q4 with result 0.
        // --------------------------------------------------------
        send_command(make_instr(OP_MEASURE, 4'd4, 4'd0, 12'd6));

        if (measure_request_valid_o != 1'b1) $fatal(1, "Test 3 failed: measure request expected");
        if (measure_qubit_o != 4'd4)         $fatal(1, "Test 3 failed: measure qubit mismatch");

        send_measurement_result(1'b0);

        $display("Test 3: Measurement result q4 = 0");
        $display("stored_valid=%0b stored_value=%0b",
                 measurement_valid_o[4],
                 measurement_results_o[4]);

        if (measurement_valid_o[4] != 1'b1)  $fatal(1, "Test 3 failed: q4 stored valid missing");
        if (measurement_results_o[4] != 1'b0)$fatal(1, "Test 3 failed: q4 stored value mismatch");

        $display("Second measurement result test PASSED");

        // --------------------------------------------------------
        // Test 4: Non-measure command should be ignored.
        // --------------------------------------------------------
        send_command(make_instr(OP_H, 4'd1, 4'd0, 12'd4));

        $display("Test 4: Non-measure command");
        $display("request=%0b busy=%0b unexpected=%0b",
                 measure_request_valid_o,
                 measurement_busy_o,
                 unexpected_result_o);

        if (measure_request_valid_o != 1'b0) $fatal(1, "Test 4 failed: H should not create measure request");
        if (measurement_busy_o != 1'b0)      $fatal(1, "Test 4 failed: H should not make controller busy");

        $display("Non-measure command ignore test PASSED");

        // --------------------------------------------------------
        // Test 5: Unexpected result without pending measurement.
        // --------------------------------------------------------
        send_measurement_result(1'b1);

        $display("Test 5: Unexpected result");
        $display("unexpected=%0b result_valid=%0b",
                 unexpected_result_o,
                 result_valid_o);

        if (unexpected_result_o != 1'b1)     $fatal(1, "Test 5 failed: unexpected_result expected");
        if (result_valid_o != 1'b0)          $fatal(1, "Test 5 failed: result should not be valid");

        $display("Unexpected result test PASSED");

        $display("measurement_controller test PASSED");
        $finish;
    end

endmodule
