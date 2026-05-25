`timescale 1ns/1ps

module tb_qc_uvm_top;

    import uvm_pkg::*;
    import qc_pkg::*;
    import qc_uvm_pkg::*;

    localparam int QUEUE_DEPTH = 4;
    localparam int NUM_QUBITS  = MAX_QUBITS;
    localparam time CLK_PERIOD = 10ns;

    logic clk_i;

    string waveform_file;
    int unsigned timeout_cycles;

    initial begin
        clk_i = 1'b0;
        forever #(CLK_PERIOD / 2) clk_i = ~clk_i;
    end

    qc_if #(
        .QUEUE_DEPTH(QUEUE_DEPTH),
        .NUM_QUBITS(NUM_QUBITS)
    ) qc_vif (
        .clk_i(clk_i)
    );

    quantum_controller_top #(
        .QUEUE_DEPTH(QUEUE_DEPTH),
        .NUM_QUBITS(NUM_QUBITS)
    ) dut (
        .clk_i                         (qc_vif.clk_i),
        .rst_ni                        (qc_vif.rst_ni),

        .instr_i                       (qc_vif.instr_i),
        .instr_valid_i                 (qc_vif.instr_valid_i),
        .instr_ready_o                 (qc_vif.instr_ready_o),

        .measurement_result_valid_i    (qc_vif.measurement_result_valid_i),
        .measurement_result_i          (qc_vif.measurement_result_i),

        .issue_valid_o                 (qc_vif.issue_valid_o),
        .issue_opcode_o                (qc_vif.issue_opcode_o),
        .issue_target_qubit_o          (qc_vif.issue_target_qubit_o),
        .issue_control_qubit_o         (qc_vif.issue_control_qubit_o),
        .issue_duration_o              (qc_vif.issue_duration_o),
        .issue_flags_o                 (qc_vif.issue_flags_o),

        .command_valid_o               (qc_vif.command_valid_o),
        .command_opcode_o              (qc_vif.command_opcode_o),
        .command_target_qubit_o        (qc_vif.command_target_qubit_o),
        .command_control_qubit_o       (qc_vif.command_control_qubit_o),
        .command_duration_o            (qc_vif.command_duration_o),
        .command_flags_o               (qc_vif.command_flags_o),

        .gate_cmd_o                    (qc_vif.gate_cmd_o),
        .measure_cmd_o                 (qc_vif.measure_cmd_o),
        .wait_cmd_o                    (qc_vif.wait_cmd_o),
        .reset_cmd_o                   (qc_vif.reset_cmd_o),
        .branch_cmd_o                  (qc_vif.branch_cmd_o),
        .nop_cmd_o                     (qc_vif.nop_cmd_o),

        .measure_request_valid_o       (qc_vif.measure_request_valid_o),
        .measure_qubit_o               (qc_vif.measure_qubit_o),
        .measurement_busy_o            (qc_vif.measurement_busy_o),

        .measurement_result_out_valid_o(qc_vif.measurement_result_out_valid_o),
        .measurement_result_qubit_o    (qc_vif.measurement_result_qubit_o),
        .measurement_result_value_o    (qc_vif.measurement_result_value_o),
        .measurement_valid_o           (qc_vif.measurement_valid_o),
        .measurement_results_o         (qc_vif.measurement_results_o),
        .unexpected_measurement_result_o(qc_vif.unexpected_measurement_result_o),

        .feedback_valid_o              (qc_vif.feedback_valid_o),
        .branch_taken_o                (qc_vif.branch_taken_o),
        .branch_target_o               (qc_vif.branch_target_o),
        .feedback_qubit_o              (qc_vif.feedback_qubit_o),
        .feedback_value_o              (qc_vif.feedback_value_o),
        .condition_checked_o           (qc_vif.condition_checked_o),
        .missing_measurement_o         (qc_vif.missing_measurement_o),

        .scheduler_stall_o             (qc_vif.scheduler_stall_o),
        .illegal_instr_o               (qc_vif.illegal_instr_o),
        .illegal_issue_o               (qc_vif.illegal_issue_o),

        .queue_count_o                 (qc_vif.queue_count_o),
        .qubit_busy_o                  (qc_vif.qubit_busy_o)
    );

    initial begin
        qc_vif.rst_ni                     = 1'b0;
        qc_vif.instr_i                    = '0;
        qc_vif.instr_valid_i              = 1'b0;
        qc_vif.measurement_result_valid_i = 1'b0;
        qc_vif.measurement_result_i       = 1'b0;
    end

    initial begin
        if (!$value$plusargs("TIMEOUT_CYCLES=%0d", timeout_cycles)) begin
            timeout_cycles = 10000;
        end

        repeat (timeout_cycles) begin
            @(posedge clk_i);
        end

        $fatal(1, "UVM test timed out after %0d cycles", timeout_cycles);
    end

    initial begin
        if ($value$plusargs("WAVE_FILE=%s", waveform_file)) begin
            $dumpfile(waveform_file);
        end else begin
            $dumpfile("results/uvm_waveforms/tb_qc_uvm_top.vcd");
        end

        if ($test$plusargs("DUMP_VCD")) begin
            $dumpvars(0, tb_qc_uvm_top);
        end
    end

    initial begin
        uvm_config_db #(virtual qc_if)::set(null, "uvm_test_top", "vif", qc_vif);
        run_test();
    end

endmodule : tb_qc_uvm_top
