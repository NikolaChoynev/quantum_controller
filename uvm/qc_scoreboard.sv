`ifndef QC_SCOREBOARD_SV
`define QC_SCOREBOARD_SV

class qc_scoreboard extends uvm_component;

    typedef struct {
        qc_opcode_e             opcode;
        logic [QUBIT_ID_W-1:0]  target_qubit;
        logic [QUBIT_ID_W-1:0]  control_qubit;
        logic [DURATION_W-1:0]  duration;
        logic [FLAGS_W-1:0]     flags;
        logic [INSTR_W-1:0]     raw_instr;
        time                    sample_time;
    } expected_instr_t;

    typedef struct {
        logic [QUBIT_ID_W-1:0]  qubit;
        bit                     value;
        time                    sample_time;
    } expected_measurement_t;

    uvm_analysis_imp #(qc_observation_item, qc_scoreboard) analysis_export;

    expected_instr_t       expected_issue_q[$];
    expected_instr_t       expected_command_q[$];
    expected_measurement_t expected_measure_request_q[$];
    expected_measurement_t outstanding_measurement_q[$];
    expected_measurement_t expected_measure_result_q[$];
    expected_instr_t       expected_feedback_q[$];

    logic [MAX_QUBITS-1:0] measurement_valid_model;
    logic [MAX_QUBITS-1:0] measurement_results_model;

    int unsigned           max_queue_depth = 4;
    int unsigned           pending_illegal_instr_count;
    int unsigned           pending_unexpected_measurement_count;

    int unsigned           instruction_count;
    int unsigned           issue_count;
    int unsigned           command_count;
    int unsigned           measure_request_count;
    int unsigned           measure_response_count;
    int unsigned           measure_result_count;
    int unsigned           feedback_count;
    int unsigned           status_count;

    `uvm_component_utils(qc_scoreboard)

    function new(string name = "qc_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        analysis_export = new("analysis_export", this);
        reset_model();
    endfunction

    function void reset_model();
        measurement_valid_model              = '0;
        measurement_results_model            = '0;
        pending_illegal_instr_count          = 0;
        pending_unexpected_measurement_count = 0;
        instruction_count                    = 0;
        issue_count                          = 0;
        command_count                        = 0;
        measure_request_count                = 0;
        measure_response_count               = 0;
        measure_result_count                 = 0;
        feedback_count                       = 0;
        status_count                         = 0;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        void'(uvm_config_db #(int unsigned)::get(
            this,
            "",
            "max_queue_depth",
            max_queue_depth
        ));
    endfunction

    function void write(qc_observation_item obs);
        case (obs.kind)
            QC_OBS_INSTRUCTION:      handle_instruction(obs);
            QC_OBS_ISSUE:            handle_issue(obs);
            QC_OBS_COMMAND:          handle_command(obs);
            QC_OBS_MEASURE_REQUEST:  handle_measure_request(obs);
            QC_OBS_MEASURE_RESPONSE: handle_measure_response(obs);
            QC_OBS_MEASURE_RESULT:   handle_measure_result(obs);
            QC_OBS_FEEDBACK:         handle_feedback(obs);
            QC_OBS_STATUS:           handle_status(obs);
            default: begin
                `uvm_error(get_type_name(),
                           $sformatf("Unknown observation kind: %0d", obs.kind))
            end
        endcase
    endfunction

    function void check_phase(uvm_phase phase);
        super.check_phase(phase);

        if (expected_issue_q.size() != 0) begin
            `uvm_warning(get_type_name(),
                         $sformatf("%0d accepted instruction(s) were not observed at issue stage",
                                   expected_issue_q.size()))
        end

        if (expected_command_q.size() != 0) begin
            `uvm_warning(get_type_name(),
                         $sformatf("%0d issued instruction(s) were not observed at command stage",
                                   expected_command_q.size()))
        end

        if (expected_measure_request_q.size() != 0) begin
            `uvm_warning(get_type_name(),
                         $sformatf("%0d expected measurement request(s) were not observed",
                                   expected_measure_request_q.size()))
        end

        if (outstanding_measurement_q.size() != 0) begin
            `uvm_warning(get_type_name(),
                         $sformatf("%0d measurement request(s) are still waiting for response",
                                   outstanding_measurement_q.size()))
        end

        if (expected_measure_result_q.size() != 0) begin
            `uvm_warning(get_type_name(),
                         $sformatf("%0d expected measurement result output(s) were not observed",
                                   expected_measure_result_q.size()))
        end

        if (expected_feedback_q.size() != 0) begin
            `uvm_warning(get_type_name(),
                         $sformatf("%0d expected feedback observation(s) were not observed",
                                   expected_feedback_q.size()))
        end
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);

        `uvm_info(get_type_name(),
                  $sformatf("Scoreboard summary: instructions=%0d issues=%0d commands=%0d measure_requests=%0d measure_responses=%0d measure_results=%0d feedback=%0d status=%0d",
                            instruction_count,
                            issue_count,
                            command_count,
                            measure_request_count,
                            measure_response_count,
                            measure_result_count,
                            feedback_count,
                            status_count),
                  UVM_LOW)
    endfunction

    function expected_instr_t expected_from_obs(qc_observation_item obs);
        expected_instr_t expected;

        expected.opcode        = obs.opcode;
        expected.target_qubit  = obs.target_qubit;
        expected.control_qubit = obs.control_qubit;
        expected.duration      = obs.duration;
        expected.flags         = obs.flags;
        expected.raw_instr     = obs.raw_instr;
        expected.sample_time   = obs.sample_time;

        return expected;
    endfunction

    function expected_measurement_t measurement_from_instr(expected_instr_t instr);
        expected_measurement_t measurement;

        measurement.qubit       = instr.target_qubit;
        measurement.value       = 1'b0;
        measurement.sample_time = instr.sample_time;

        return measurement;
    endfunction

    function bit is_legal_opcode(qc_opcode_e opcode);
        case (opcode)
            OP_NOP,
            OP_H,
            OP_X,
            OP_Z,
            OP_CNOT,
            OP_MEASURE,
            OP_WAIT,
            OP_RESET,
            OP_BRANCH: return 1'b1;
            default:   return 1'b0;
        endcase
    endfunction

    function bit is_conditional_branch(expected_instr_t instr);
        return instr.flags[FLAG_CONDITIONAL_BIT] ||
               instr.flags[FLAG_FEEDBACK_BIT];
    endfunction

    function int unsigned command_class_count(qc_observation_item obs);
        return int'(obs.gate_cmd) +
               int'(obs.measure_cmd) +
               int'(obs.wait_cmd) +
               int'(obs.reset_cmd) +
               int'(obs.branch_cmd) +
               int'(obs.nop_cmd);
    endfunction

    function void handle_instruction(qc_observation_item obs);
        expected_instr_t expected;

        instruction_count++;

        if (!is_legal_opcode(obs.opcode)) begin
            pending_illegal_instr_count++;
            return;
        end

        if (!obs.flags[FLAG_VALID_BIT]) begin
            return;
        end

        expected = expected_from_obs(obs);
        expected_issue_q.push_back(expected);
    endfunction

    function void handle_issue(qc_observation_item obs);
        expected_instr_t expected;

        issue_count++;

        if (expected_issue_q.size() == 0) begin
            `uvm_error(get_type_name(),
                       $sformatf("Unexpected issue observation: %s",
                                 obs.convert2string()))
            return;
        end

        expected = expected_issue_q.pop_front();
        compare_instruction_fields("issue", expected, obs, 1'b1);
        expected_command_q.push_back(expected);
    endfunction

    function void handle_command(qc_observation_item obs);
        expected_instr_t expected;

        command_count++;

        if (expected_command_q.size() == 0) begin
            `uvm_error(get_type_name(),
                       $sformatf("Unexpected command observation: %s",
                                 obs.convert2string()))
            return;
        end

        expected = expected_command_q.pop_front();

        if (expected.opcode != OP_NOP) begin
            compare_instruction_fields("command", expected, obs, 1'b1);
        end

        check_command_classification(expected, obs);

        if (expected.opcode == OP_MEASURE) begin
            expected_measure_request_q.push_back(measurement_from_instr(expected));
        end

        if (expected.opcode == OP_BRANCH) begin
            expected_feedback_q.push_back(expected);
        end
    endfunction

    function void handle_measure_request(qc_observation_item obs);
        expected_measurement_t expected;

        measure_request_count++;

        if (expected_measure_request_q.size() == 0) begin
            `uvm_error(get_type_name(),
                       $sformatf("Unexpected measurement request observation: %s",
                                 obs.convert2string()))
            return;
        end

        expected = expected_measure_request_q.pop_front();

        if (!obs.measure_request_valid) begin
            `uvm_error(get_type_name(), "Measurement request observation is not marked valid")
        end

        if (obs.measure_qubit !== expected.qubit) begin
            `uvm_error(get_type_name(),
                       $sformatf("Measurement request qubit mismatch: expected q%0d observed q%0d",
                                 expected.qubit,
                                 obs.measure_qubit))
        end

        outstanding_measurement_q.push_back(expected);
    endfunction

    function void handle_measure_response(qc_observation_item obs);
        expected_measurement_t expected;

        measure_response_count++;

        if (outstanding_measurement_q.size() == 0) begin
            pending_unexpected_measurement_count++;
            return;
        end

        expected       = outstanding_measurement_q.pop_front();
        expected.value = obs.measurement_response_value;

        expected_measure_result_q.push_back(expected);
    endfunction

    function void handle_measure_result(qc_observation_item obs);
        expected_measurement_t expected;

        measure_result_count++;

        if (expected_measure_result_q.size() == 0) begin
            `uvm_error(get_type_name(),
                       $sformatf("Unexpected measurement result observation: %s",
                                 obs.convert2string()))
            return;
        end

        expected = expected_measure_result_q.pop_front();

        if (!obs.measurement_result_valid) begin
            `uvm_error(get_type_name(), "Measurement result observation is not marked valid")
        end

        if (obs.measurement_result_qubit !== expected.qubit) begin
            `uvm_error(get_type_name(),
                       $sformatf("Measurement result qubit mismatch: expected q%0d observed q%0d",
                                 expected.qubit,
                                 obs.measurement_result_qubit))
        end

        if (obs.measurement_result_value !== expected.value) begin
            `uvm_error(get_type_name(),
                       $sformatf("Measurement result value mismatch for q%0d: expected %0b observed %0b",
                                 expected.qubit,
                                 expected.value,
                                 obs.measurement_result_value))
        end

        measurement_valid_model[expected.qubit]   = 1'b1;
        measurement_results_model[expected.qubit] = expected.value;

        if (obs.measurement_valid[expected.qubit] !== 1'b1) begin
            `uvm_error(get_type_name(),
                       $sformatf("measurement_valid_o[%0d] was not set after result output",
                                 expected.qubit))
        end

        if (obs.measurement_results[expected.qubit] !== expected.value) begin
            `uvm_error(get_type_name(),
                       $sformatf("measurement_results_o[%0d] mismatch: expected %0b observed %0b",
                                 expected.qubit,
                                 expected.value,
                                 obs.measurement_results[expected.qubit]))
        end
    endfunction

    function void handle_feedback(qc_observation_item obs);
        expected_instr_t expected;
        bit              expected_conditional;
        bit              expected_selected_valid;
        bit              expected_selected_value;
        bit              expected_branch_taken;
        bit              expected_condition_checked;
        bit              expected_missing_measurement;
        bit              expected_feedback_value;

        feedback_count++;

        if (expected_feedback_q.size() == 0) begin
            `uvm_error(get_type_name(),
                       $sformatf("Unexpected feedback observation: %s",
                                 obs.convert2string()))
            return;
        end

        expected = expected_feedback_q.pop_front();
        expected_conditional = is_conditional_branch(expected);
        expected_selected_valid = measurement_valid_model[expected.target_qubit];
        expected_selected_value = measurement_results_model[expected.target_qubit];

        expected_branch_taken        = 1'b0;
        expected_condition_checked   = 1'b0;
        expected_missing_measurement = 1'b0;
        expected_feedback_value      = 1'b0;

        if (expected_conditional) begin
            if (expected_selected_valid) begin
                expected_condition_checked = 1'b1;
                expected_feedback_value    = expected_selected_value;
                expected_branch_taken      = (expected_selected_value ==
                                             expected.flags[FLAG_EXPECTED_BIT]);
            end else begin
                expected_missing_measurement = 1'b1;
            end
        end else begin
            expected_branch_taken = 1'b1;
        end

        if (!obs.feedback_valid) begin
            `uvm_error(get_type_name(), "Feedback observation is not marked valid")
        end

        if (obs.feedback_qubit !== expected.target_qubit) begin
            `uvm_error(get_type_name(),
                       $sformatf("Feedback qubit mismatch: expected q%0d observed q%0d",
                                 expected.target_qubit,
                                 obs.feedback_qubit))
        end

        if (obs.branch_target !== expected.duration) begin
            `uvm_error(get_type_name(),
                       $sformatf("Branch target mismatch: expected %0d observed %0d",
                                 expected.duration,
                                 obs.branch_target))
        end

        if (obs.branch_taken !== expected_branch_taken) begin
            `uvm_error(get_type_name(),
                       $sformatf("Branch decision mismatch: expected %0b observed %0b",
                                 expected_branch_taken,
                                 obs.branch_taken))
        end

        if (obs.condition_checked !== expected_condition_checked) begin
            `uvm_error(get_type_name(),
                       $sformatf("condition_checked mismatch: expected %0b observed %0b",
                                 expected_condition_checked,
                                 obs.condition_checked))
        end

        if (obs.missing_measurement !== expected_missing_measurement) begin
            `uvm_error(get_type_name(),
                       $sformatf("missing_measurement mismatch: expected %0b observed %0b",
                                 expected_missing_measurement,
                                 obs.missing_measurement))
        end

        if (obs.feedback_value !== expected_feedback_value) begin
            `uvm_error(get_type_name(),
                       $sformatf("feedback_value mismatch: expected %0b observed %0b",
                                 expected_feedback_value,
                                 obs.feedback_value))
        end

        if (expected_branch_taken) begin
            expected_issue_q.delete();
        end
    endfunction

    function void handle_status(qc_observation_item obs);
        status_count++;

        if (obs.illegal_instr) begin
            if (pending_illegal_instr_count == 0) begin
                `uvm_error(get_type_name(),
                           $sformatf("Unexpected illegal_instr observation: %s",
                                     obs.convert2string()))
            end else begin
                pending_illegal_instr_count--;
            end
        end

        if (obs.illegal_issue) begin
            `uvm_error(get_type_name(),
                       $sformatf("illegal_issue_o should not occur for decoded legal instructions: %s",
                                 obs.convert2string()))
        end

        if (obs.unexpected_measurement_result) begin
            if (pending_unexpected_measurement_count == 0) begin
                `uvm_error(get_type_name(),
                           $sformatf("Unexpected measurement result flag without unmatched response: %s",
                                     obs.convert2string()))
            end else begin
                pending_unexpected_measurement_count--;
            end
        end

        if (obs.queue_count > max_queue_depth) begin
            `uvm_error(get_type_name(),
                       $sformatf("Queue count exceeded configured depth: count=%0d depth=%0d",
                                 obs.queue_count,
                                 max_queue_depth))
        end

        if ($isunknown(obs.qubit_busy)) begin
            `uvm_error(get_type_name(), "qubit_busy_o contains unknown values")
        end
    endfunction

    function void compare_instruction_fields(
        string stage,
        expected_instr_t expected,
        qc_observation_item obs,
        bit compare_flags
    );
        if (obs.opcode !== expected.opcode) begin
            `uvm_error(get_type_name(),
                       $sformatf("%s opcode mismatch: expected %s observed %s",
                                 stage,
                                 expected.opcode.name(),
                                 obs.opcode.name()))
        end

        if (obs.target_qubit !== expected.target_qubit) begin
            `uvm_error(get_type_name(),
                       $sformatf("%s target qubit mismatch: expected q%0d observed q%0d",
                                 stage,
                                 expected.target_qubit,
                                 obs.target_qubit))
        end

        if (obs.control_qubit !== expected.control_qubit) begin
            `uvm_error(get_type_name(),
                       $sformatf("%s control qubit mismatch: expected q%0d observed q%0d",
                                 stage,
                                 expected.control_qubit,
                                 obs.control_qubit))
        end

        if (obs.duration !== expected.duration) begin
            `uvm_error(get_type_name(),
                       $sformatf("%s duration mismatch: expected %0d observed %0d",
                                 stage,
                                 expected.duration,
                                 obs.duration))
        end

        if (compare_flags && obs.flags !== expected.flags) begin
            `uvm_error(get_type_name(),
                       $sformatf("%s flags mismatch: expected 0x%0h observed 0x%0h",
                                 stage,
                                 expected.flags,
                                 obs.flags))
        end
    endfunction

    function void check_command_classification(
        expected_instr_t expected,
        qc_observation_item obs
    );
        if (command_class_count(obs) != 1) begin
            `uvm_error(get_type_name(),
                       $sformatf("Command classification is not one-hot for opcode %s: %s",
                                 expected.opcode.name(),
                                 obs.convert2string()))
        end

        case (expected.opcode)
            OP_NOP: begin
                check_command_bit("nop_cmd", obs.nop_cmd, 1'b1, expected);
            end

            OP_H,
            OP_X,
            OP_Z,
            OP_CNOT: begin
                check_command_bit("gate_cmd", obs.gate_cmd, 1'b1, expected);
            end

            OP_MEASURE: begin
                check_command_bit("measure_cmd", obs.measure_cmd, 1'b1, expected);
            end

            OP_WAIT: begin
                check_command_bit("wait_cmd", obs.wait_cmd, 1'b1, expected);
            end

            OP_RESET: begin
                check_command_bit("reset_cmd", obs.reset_cmd, 1'b1, expected);
            end

            OP_BRANCH: begin
                check_command_bit("branch_cmd", obs.branch_cmd, 1'b1, expected);
            end

            default: begin
                `uvm_error(get_type_name(),
                           $sformatf("Unexpected opcode reached command classification check: %s",
                                     expected.opcode.name()))
            end
        endcase
    endfunction

    function void check_command_bit(
        string bit_name,
        bit observed,
        bit expected_value,
        expected_instr_t expected
    );
        if (observed !== expected_value) begin
            `uvm_error(get_type_name(),
                       $sformatf("%s mismatch for opcode %s: expected %0b observed %0b",
                                 bit_name,
                                 expected.opcode.name(),
                                 expected_value,
                                 observed))
        end
    endfunction

endclass : qc_scoreboard

`endif
