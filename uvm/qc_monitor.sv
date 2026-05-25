`ifndef QC_MONITOR_SV
`define QC_MONITOR_SV

class qc_monitor extends uvm_monitor;

    virtual qc_if vif;

    uvm_analysis_port #(qc_observation_item) analysis_port;

    bit                    have_status_sample;
    int unsigned           last_queue_count;
    logic [MAX_QUBITS-1:0] last_qubit_busy;

    `uvm_component_utils(qc_monitor)

    function new(string name = "qc_monitor", uvm_component parent = null);
        super.new(name, parent);
        analysis_port = new("analysis_port", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db #(virtual qc_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal(get_type_name(), "Virtual interface 'vif' was not provided")
        end
    endfunction

    task run_phase(uvm_phase phase);
        wait_for_reset_release();

        forever begin
            @(vif.mon_cb);

            if (vif.mon_cb.rst_ni !== 1'b1) begin
                have_status_sample = 1'b0;
                continue;
            end

            sample_cycle();
        end
    endtask

    task wait_for_reset_release();
        do begin
            @(vif.mon_cb);
        end while (vif.mon_cb.rst_ni !== 1'b1);
    endtask

    function void sample_cycle();
        if (vif.mon_cb.instr_valid_i && vif.mon_cb.instr_ready_o) begin
            sample_instruction();
        end

        if (vif.mon_cb.issue_valid_o) begin
            sample_issue();
        end

        if (vif.mon_cb.command_valid_o ||
            vif.mon_cb.gate_cmd_o ||
            vif.mon_cb.measure_cmd_o ||
            vif.mon_cb.wait_cmd_o ||
            vif.mon_cb.reset_cmd_o ||
            vif.mon_cb.branch_cmd_o ||
            vif.mon_cb.nop_cmd_o) begin
            sample_command();
        end

        if (vif.mon_cb.measure_request_valid_o) begin
            sample_measure_request();
        end

        if (vif.mon_cb.measurement_result_valid_i) begin
            sample_measure_response();
        end

        if (vif.mon_cb.measurement_result_out_valid_o) begin
            sample_measure_result();
        end

        if (vif.mon_cb.feedback_valid_o ||
            vif.mon_cb.branch_taken_o ||
            vif.mon_cb.condition_checked_o ||
            vif.mon_cb.missing_measurement_o) begin
            sample_feedback();
        end

        if (should_sample_status()) begin
            sample_status();
        end
    endfunction

    function qc_observation_item create_observation(
        input string name,
        input qc_observation_kind_e kind
    );
        qc_observation_item obs;

        obs = qc_observation_item::type_id::create(name);
        obs.kind        = kind;
        obs.sample_time = $time;

        return obs;
    endfunction

    function void publish(qc_observation_item obs);
        `uvm_info(get_type_name(), obs.convert2string(), UVM_HIGH)
        analysis_port.write(obs);
    endfunction

    function void sample_instruction();
        qc_observation_item obs;

        obs = create_observation("instruction_obs", QC_OBS_INSTRUCTION);
        obs.load_raw(vif.mon_cb.instr_i);

        publish(obs);
    endfunction

    function void sample_issue();
        qc_observation_item obs;

        obs = create_observation("issue_obs", QC_OBS_ISSUE);
        obs.load_fields(
            vif.mon_cb.issue_opcode_o,
            vif.mon_cb.issue_target_qubit_o,
            vif.mon_cb.issue_control_qubit_o,
            vif.mon_cb.issue_duration_o,
            vif.mon_cb.issue_flags_o
        );

        publish(obs);
    endfunction

    function void sample_command();
        qc_observation_item obs;

        obs = create_observation("command_obs", QC_OBS_COMMAND);
        obs.load_fields(
            vif.mon_cb.command_opcode_o,
            vif.mon_cb.command_target_qubit_o,
            vif.mon_cb.command_control_qubit_o,
            vif.mon_cb.command_duration_o,
            vif.mon_cb.command_flags_o
        );
        obs.gate_cmd    = vif.mon_cb.gate_cmd_o;
        obs.measure_cmd = vif.mon_cb.measure_cmd_o;
        obs.wait_cmd    = vif.mon_cb.wait_cmd_o;
        obs.reset_cmd   = vif.mon_cb.reset_cmd_o;
        obs.branch_cmd  = vif.mon_cb.branch_cmd_o;
        obs.nop_cmd     = vif.mon_cb.nop_cmd_o;

        publish(obs);
    endfunction

    function void sample_measure_request();
        qc_observation_item obs;

        obs = create_observation("measure_request_obs", QC_OBS_MEASURE_REQUEST);
        obs.measure_request_valid = vif.mon_cb.measure_request_valid_o;
        obs.measure_qubit         = vif.mon_cb.measure_qubit_o;
        obs.measurement_busy      = vif.mon_cb.measurement_busy_o;

        publish(obs);
    endfunction

    function void sample_measure_response();
        qc_observation_item obs;

        obs = create_observation("measure_response_obs", QC_OBS_MEASURE_RESPONSE);
        obs.measurement_response_valid = vif.mon_cb.measurement_result_valid_i;
        obs.measurement_response_value = vif.mon_cb.measurement_result_i;

        publish(obs);
    endfunction

    function void sample_measure_result();
        qc_observation_item obs;

        obs = create_observation("measure_result_obs", QC_OBS_MEASURE_RESULT);
        obs.measurement_result_valid = vif.mon_cb.measurement_result_out_valid_o;
        obs.measurement_result_qubit = vif.mon_cb.measurement_result_qubit_o;
        obs.measurement_result_value = vif.mon_cb.measurement_result_value_o;
        obs.measurement_valid        = vif.mon_cb.measurement_valid_o;
        obs.measurement_results      = vif.mon_cb.measurement_results_o;

        publish(obs);
    endfunction

    function void sample_feedback();
        qc_observation_item obs;

        obs = create_observation("feedback_obs", QC_OBS_FEEDBACK);
        obs.feedback_valid      = vif.mon_cb.feedback_valid_o;
        obs.branch_taken        = vif.mon_cb.branch_taken_o;
        obs.branch_target       = vif.mon_cb.branch_target_o;
        obs.feedback_qubit      = vif.mon_cb.feedback_qubit_o;
        obs.feedback_value      = vif.mon_cb.feedback_value_o;
        obs.condition_checked   = vif.mon_cb.condition_checked_o;
        obs.missing_measurement = vif.mon_cb.missing_measurement_o;

        publish(obs);
    endfunction

    function bit should_sample_status();
        bit changed;

        changed = (have_status_sample == 1'b0) ||
                  (last_queue_count != int'(vif.mon_cb.queue_count_o)) ||
                  (last_qubit_busy != vif.mon_cb.qubit_busy_o);

        return changed ||
               vif.mon_cb.scheduler_stall_o ||
               vif.mon_cb.illegal_instr_o ||
               vif.mon_cb.illegal_issue_o ||
               vif.mon_cb.unexpected_measurement_result_o;
    endfunction

    function void sample_status();
        qc_observation_item obs;

        obs = create_observation("status_obs", QC_OBS_STATUS);
        obs.scheduler_stall              = vif.mon_cb.scheduler_stall_o;
        obs.illegal_instr                = vif.mon_cb.illegal_instr_o;
        obs.illegal_issue                = vif.mon_cb.illegal_issue_o;
        obs.unexpected_measurement_result = vif.mon_cb.unexpected_measurement_result_o;
        obs.queue_count                  = vif.mon_cb.queue_count_o;
        obs.qubit_busy                   = vif.mon_cb.qubit_busy_o;

        last_queue_count    = obs.queue_count;
        last_qubit_busy     = obs.qubit_busy;
        have_status_sample  = 1'b1;

        publish(obs);
    endfunction

endclass : qc_monitor

`endif
