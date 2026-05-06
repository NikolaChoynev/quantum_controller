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

    logic                   measurement_result_valid_i;
    logic                   measurement_result_i;

    logic                   issue_valid_o;
    qc_opcode_e             issue_opcode_o;
    logic [QUBIT_ID_W-1:0]  issue_target_qubit_o;
    logic [QUBIT_ID_W-1:0]  issue_control_qubit_o;
    logic [DURATION_W-1:0]  issue_duration_o;
    logic [FLAGS_W-1:0]     issue_flags_o;

    logic                   command_valid_o;
    qc_opcode_e             command_opcode_o;
    logic [QUBIT_ID_W-1:0]  command_target_qubit_o;
    logic [QUBIT_ID_W-1:0]  command_control_qubit_o;
    logic [DURATION_W-1:0]  command_duration_o;
    logic [FLAGS_W-1:0]     command_flags_o;

    logic                   gate_cmd_o;
    logic                   measure_cmd_o;
    logic                   wait_cmd_o;
    logic                   reset_cmd_o;
    logic                   branch_cmd_o;
    logic                   nop_cmd_o;

    logic                   measure_request_valid_o;
    logic [QUBIT_ID_W-1:0]  measure_qubit_o;
    logic                   measurement_busy_o;

    logic                   measurement_result_out_valid_o;
    logic [QUBIT_ID_W-1:0]  measurement_result_qubit_o;
    logic                   measurement_result_value_o;
    logic [NUM_QUBITS-1:0]  measurement_valid_o;
    logic [NUM_QUBITS-1:0]  measurement_results_o;
    logic                   unexpected_measurement_result_o;

    logic                   scheduler_stall_o;
    logic                   illegal_instr_o;
    logic                   illegal_issue_o;

    logic [$clog2(QUEUE_DEPTH+1)-1:0] queue_count_o;
    logic [NUM_QUBITS-1:0]             qubit_busy_o;

    quantum_controller_top #(
        .QUEUE_DEPTH(QUEUE_DEPTH),
        .NUM_QUBITS(NUM_QUBITS)
    ) dut (
        .clk_i                          (clk_i),
        .rst_ni                         (rst_ni),

        .instr_i                        (instr_i),
        .instr_valid_i                  (instr_valid_i),
        .instr_ready_o                  (instr_ready_o),

        .measurement_result_valid_i     (measurement_result_valid_i),
        .measurement_result_i           (measurement_result_i),

        .issue_valid_o                  (issue_valid_o),
        .issue_opcode_o                 (issue_opcode_o),
        .issue_target_qubit_o           (issue_target_qubit_o),
        .issue_control_qubit_o          (issue_control_qubit_o),
        .issue_duration_o               (issue_duration_o),
        .issue_flags_o                  (issue_flags_o),

        .command_valid_o                (command_valid_o),
        .command_opcode_o               (command_opcode_o),
        .command_target_qubit_o         (command_target_qubit_o),
        .command_control_qubit_o        (command_control_qubit_o),
        .command_duration_o             (command_duration_o),
        .command_flags_o                (command_flags_o),

        .gate_cmd_o                     (gate_cmd_o),
        .measure_cmd_o                  (measure_cmd_o),
        .wait_cmd_o                     (wait_cmd_o),
        .reset_cmd_o                    (reset_cmd_o),
        .branch_cmd_o                   (branch_cmd_o),
        .nop_cmd_o                      (nop_cmd_o),

        .measure_request_valid_o        (measure_request_valid_o),
        .measure_qubit_o                (measure_qubit_o),
        .measurement_busy_o             (measurement_busy_o),

        .measurement_result_out_valid_o (measurement_result_out_valid_o),
        .measurement_result_qubit_o     (measurement_result_qubit_o),
        .measurement_result_value_o     (measurement_result_value_o),
        .measurement_valid_o            (measurement_valid_o),
        .measurement_results_o          (measurement_results_o),
        .unexpected_measurement_result_o(unexpected_measurement_result_o),

        .scheduler_stall_o              (scheduler_stall_o),
        .illegal_instr_o                (illegal_instr_o),
        .illegal_issue_o                (illegal_issue_o),

        .queue_count_o                  (queue_count_o),
        .qubit_busy_o                   (qubit_busy_o)
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

    task automatic wait_for_command();
        begin
            while (command_valid_o != 1'b1) begin
                @(posedge clk_i);
                #1;
            end
        end
    endtask

    task automatic wait_for_measure_request();
        begin
            while (measure_request_valid_o != 1'b1) begin
                @(posedge clk_i);
                #1;
            end
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
        $dumpfile("results/waveforms/quantum_controller_top.vcd");
        $dumpvars(0, tb_quantum_controller_top);

        instr_i                    = '0;
        instr_valid_i              = 1'b0;
        measurement_result_valid_i = 1'b0;
        measurement_result_i       = 1'b0;
        rst_ni                     = 1'b0;

        repeat (2) @(negedge clk_i);
        rst_ni = 1'b1;
        #1;

        if (queue_count_o != 0)                 $fatal(1, "Queue count should be 0 after reset");
        if (issue_valid_o != 1'b0)              $fatal(1, "Issue valid should be 0 after reset");
        if (command_valid_o != 1'b0)            $fatal(1, "Command valid should be 0 after reset");
        if (measurement_busy_o != 1'b0)         $fatal(1, "Measurement controller should not be busy after reset");
        if (measurement_valid_o != '0)          $fatal(1, "No measurement results should be valid after reset");

        $display("Reset test PASSED");

        // --------------------------------------------------------
        // Test 1: H q0 -> gate command
        // --------------------------------------------------------
        send_instruction({4'h1, 4'd0, 4'd0, 12'd4, 4'b1000, 4'd0});

        wait_for_command();

        $display("Test 1: H q0 command");
        $display("cmd_valid=%0b opcode=%0h target=%0d gate=%0b",
                 command_valid_o, command_opcode_o,
                 command_target_qubit_o, gate_cmd_o);

        if (command_opcode_o != OP_H)          $fatal(1, "Test 1 failed: command opcode mismatch");
        if (command_target_qubit_o != 4'd0)    $fatal(1, "Test 1 failed: command target mismatch");
        if (gate_cmd_o != 1'b1)                $fatal(1, "Test 1 failed: gate command expected");

        // --------------------------------------------------------
        // Test 2: MEASURE q3 -> measure command -> measure request
        // --------------------------------------------------------
        send_instruction({4'h5, 4'd3, 4'd0, 12'd6, 4'b1000, 4'd0});

        wait_for_command();

        $display("Test 2: MEASURE q3 command");
        $display("cmd_valid=%0b opcode=%0h target=%0d measure_cmd=%0b",
                 command_valid_o, command_opcode_o,
                 command_target_qubit_o, measure_cmd_o);

        if (command_opcode_o != OP_MEASURE)    $fatal(1, "Test 2 failed: command opcode mismatch");
        if (command_target_qubit_o != 4'd3)    $fatal(1, "Test 2 failed: command target mismatch");
        if (measure_cmd_o != 1'b1)             $fatal(1, "Test 2 failed: measure command expected");

        wait_for_measure_request();

        $display("Test 2: Measurement request");
        $display("request=%0b qubit=%0d busy=%0b",
                 measure_request_valid_o,
                 measure_qubit_o,
                 measurement_busy_o);

        if (measure_request_valid_o != 1'b1)   $fatal(1, "Test 2 failed: measure request expected");
        if (measure_qubit_o != 4'd3)           $fatal(1, "Test 2 failed: measure request qubit mismatch");
        if (measurement_busy_o != 1'b1)        $fatal(1, "Test 2 failed: measurement controller should be busy");

        // --------------------------------------------------------
        // Test 3: External measurement result for q3 = 1
        // --------------------------------------------------------
        send_measurement_result(1'b1);

        $display("Test 3: Measurement result q3 = 1");
        $display("result_valid=%0b qubit=%0d value=%0b stored_valid=%0b stored_value=%0b",
                 measurement_result_out_valid_o,
                 measurement_result_qubit_o,
                 measurement_result_value_o,
                 measurement_valid_o[3],
                 measurement_results_o[3]);

        if (measurement_result_out_valid_o != 1'b1) $fatal(1, "Test 3 failed: result valid expected");
        if (measurement_result_qubit_o != 4'd3)     $fatal(1, "Test 3 failed: result qubit mismatch");
        if (measurement_result_value_o != 1'b1)     $fatal(1, "Test 3 failed: result value mismatch");
        if (measurement_valid_o[3] != 1'b1)         $fatal(1, "Test 3 failed: stored valid missing");
        if (measurement_results_o[3] != 1'b1)       $fatal(1, "Test 3 failed: stored result mismatch");

        $display("Measurement result integration test PASSED");

        // --------------------------------------------------------
        // Test 4: WAIT -> wait command
        // --------------------------------------------------------
        send_instruction({4'h6, 4'd0, 4'd0, 12'd5, 4'b1000, 4'd0});

        wait_for_command();

        $display("Test 4: WAIT command");
        $display("cmd_valid=%0b opcode=%0h duration=%0d wait=%0b",
                 command_valid_o, command_opcode_o,
                 command_duration_o, wait_cmd_o);

        if (command_opcode_o != OP_WAIT)       $fatal(1, "Test 4 failed: command opcode mismatch");
        if (command_duration_o != 12'd5)       $fatal(1, "Test 4 failed: wait duration mismatch");
        if (wait_cmd_o != 1'b1)                $fatal(1, "Test 4 failed: wait command expected");

        // --------------------------------------------------------
        // Test 5: Invalid opcode should be rejected before execution.
        // --------------------------------------------------------
        send_instruction({4'hF, 4'd0, 4'd0, 12'd1, 4'b1000, 4'd0});

        $display("Test 5: Invalid opcode");
        $display("illegal_instr=%0b illegal_issue=%0b count=%0d",
                 illegal_instr_o, illegal_issue_o, queue_count_o);

        if (illegal_instr_o != 1'b1)           $fatal(1, "Test 5 failed: invalid opcode not detected");
        if (illegal_issue_o != 1'b0)           $fatal(1, "Test 5 failed: invalid opcode reached execution controller");

        $display("quantum_controller_top measurement integration test PASSED");
        $finish;
    end

endmodule
