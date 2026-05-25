`ifndef QC_COVERAGE_SV
`define QC_COVERAGE_SV

typedef enum int unsigned {
    QC_CMD_CLASS_NONE,
    QC_CMD_CLASS_GATE,
    QC_CMD_CLASS_MEASURE,
    QC_CMD_CLASS_WAIT,
    QC_CMD_CLASS_RESET,
    QC_CMD_CLASS_BRANCH,
    QC_CMD_CLASS_NOP,
    QC_CMD_CLASS_MULTI
} qc_command_class_e;

class qc_coverage extends uvm_subscriber #(qc_observation_item);

    qc_observation_kind_e sampled_kind;
    qc_opcode_e           sampled_opcode;
    qc_command_class_e    sampled_command_class;

    bit                   sampled_valid_flag;
    bit                   sampled_conditional_flag;
    bit                   sampled_feedback_flag;
    bit                   sampled_expected_flag;

    bit                   sampled_measure_request;
    bit                   sampled_measure_response;
    bit                   sampled_measure_response_value;
    bit                   sampled_measure_result;
    bit                   sampled_measure_result_value;
    bit                   sampled_measurement_busy;
    bit                   sampled_unexpected_measurement_result;

    bit                   sampled_feedback_valid;
    bit                   sampled_branch_taken;
    bit                   sampled_condition_checked;
    bit                   sampled_missing_measurement;
    bit                   sampled_feedback_value;

    bit                   sampled_scheduler_stall;
    bit                   sampled_illegal_instr;
    bit                   sampled_illegal_issue;
    int unsigned          sampled_queue_count;
    int unsigned          sampled_busy_count;

    int unsigned          instruction_samples;
    int unsigned          issue_samples;
    int unsigned          command_samples;
    int unsigned          measurement_samples;
    int unsigned          feedback_samples;
    int unsigned          status_samples;

    `uvm_component_utils(qc_coverage)

    covergroup observation_cg with function sample();
        option.per_instance = 1;

        kind_cp: coverpoint sampled_kind {
            bins instruction      = {QC_OBS_INSTRUCTION};
            bins issue            = {QC_OBS_ISSUE};
            bins command          = {QC_OBS_COMMAND};
            bins measure_request  = {QC_OBS_MEASURE_REQUEST};
            bins measure_response = {QC_OBS_MEASURE_RESPONSE};
            bins measure_result   = {QC_OBS_MEASURE_RESULT};
            bins feedback         = {QC_OBS_FEEDBACK};
            bins status           = {QC_OBS_STATUS};
        }
    endgroup

    covergroup instruction_cg with function sample();
        option.per_instance = 1;

        opcode_cp: coverpoint sampled_opcode {
            bins nop     = {OP_NOP};
            bins h       = {OP_H};
            bins x       = {OP_X};
            bins z       = {OP_Z};
            bins cnot    = {OP_CNOT};
            bins measure = {OP_MEASURE};
            bins wait_op = {OP_WAIT};
            bins reset   = {OP_RESET};
            bins branch  = {OP_BRANCH};
            bins invalid = default;
        }

        valid_flag_cp: coverpoint sampled_valid_flag {
            bins invalid_flag = {0};
            bins valid_flag   = {1};
        }

        conditional_flag_cp: coverpoint sampled_conditional_flag {
            bins off = {0};
            bins on  = {1};
        }

        feedback_flag_cp: coverpoint sampled_feedback_flag {
            bins off = {0};
            bins on  = {1};
        }

        expected_flag_cp: coverpoint sampled_expected_flag {
            bins expected_zero = {0};
            bins expected_one  = {1};
        }

        opcode_x_valid: cross opcode_cp, valid_flag_cp;
        branch_x_flags: cross opcode_cp, conditional_flag_cp, feedback_flag_cp, expected_flag_cp {
            ignore_bins non_branch = binsof(opcode_cp) intersect {
                OP_NOP,
                OP_H,
                OP_X,
                OP_Z,
                OP_CNOT,
                OP_MEASURE,
                OP_WAIT,
                OP_RESET
            };
        }
    endgroup

    covergroup command_cg with function sample();
        option.per_instance = 1;

        opcode_cp: coverpoint sampled_opcode {
            bins nop     = {OP_NOP};
            bins gates   = {OP_H, OP_X, OP_Z, OP_CNOT};
            bins measure = {OP_MEASURE};
            bins wait_op = {OP_WAIT};
            bins reset   = {OP_RESET};
            bins branch  = {OP_BRANCH};
            bins invalid = default;
        }

        command_class_cp: coverpoint sampled_command_class {
            bins none    = {QC_CMD_CLASS_NONE};
            bins gate    = {QC_CMD_CLASS_GATE};
            bins measure = {QC_CMD_CLASS_MEASURE};
            bins wait_op = {QC_CMD_CLASS_WAIT};
            bins reset   = {QC_CMD_CLASS_RESET};
            bins branch  = {QC_CMD_CLASS_BRANCH};
            bins nop     = {QC_CMD_CLASS_NOP};
            bins multi   = {QC_CMD_CLASS_MULTI};
        }

        opcode_x_command_class: cross opcode_cp, command_class_cp;
    endgroup

    covergroup measurement_cg with function sample();
        option.per_instance = 1;

        request_cp: coverpoint sampled_measure_request {
            bins no_request = {0};
            bins request    = {1};
        }

        response_cp: coverpoint sampled_measure_response {
            bins no_response = {0};
            bins response    = {1};
        }

        response_value_cp: coverpoint sampled_measure_response_value {
            bins zero = {0};
            bins one  = {1};
        }

        result_cp: coverpoint sampled_measure_result {
            bins no_result = {0};
            bins result    = {1};
        }

        result_value_cp: coverpoint sampled_measure_result_value {
            bins zero = {0};
            bins one  = {1};
        }

        busy_cp: coverpoint sampled_measurement_busy {
            bins idle = {0};
            bins busy = {1};
        }

        unexpected_cp: coverpoint sampled_unexpected_measurement_result {
            bins expected_path   = {0};
            bins unexpected_path = {1};
        }

        response_x_value: cross response_cp, response_value_cp;
        result_x_value:   cross result_cp, result_value_cp;
    endgroup

    covergroup feedback_cg with function sample();
        option.per_instance = 1;

        feedback_valid_cp: coverpoint sampled_feedback_valid {
            bins inactive = {0};
            bins active   = {1};
        }

        branch_taken_cp: coverpoint sampled_branch_taken {
            bins not_taken = {0};
            bins taken     = {1};
        }

        condition_checked_cp: coverpoint sampled_condition_checked {
            bins unchecked = {0};
            bins checked   = {1};
        }

        missing_measurement_cp: coverpoint sampled_missing_measurement {
            bins present = {0};
            bins missing = {1};
        }

        feedback_value_cp: coverpoint sampled_feedback_value {
            bins zero = {0};
            bins one  = {1};
        }

        branch_outcome_x_condition: cross branch_taken_cp,
                                          condition_checked_cp,
                                          missing_measurement_cp;
        checked_x_feedback_value: cross condition_checked_cp, feedback_value_cp;
    endgroup

    covergroup status_cg with function sample();
        option.per_instance = 1;

        stall_cp: coverpoint sampled_scheduler_stall {
            bins no_stall = {0};
            bins stall    = {1};
        }

        illegal_instr_cp: coverpoint sampled_illegal_instr {
            bins legal_path   = {0};
            bins illegal_path = {1};
        }

        illegal_issue_cp: coverpoint sampled_illegal_issue {
            bins legal_issue   = {0};
            bins illegal_issue = {1};
        }

        unexpected_measurement_cp: coverpoint sampled_unexpected_measurement_result {
            bins normal     = {0};
            bins unexpected = {1};
        }

        queue_count_cp: coverpoint sampled_queue_count {
            bins empty       = {0};
            bins non_empty   = {[1:3]};
            bins full_or_more = {[4:16]};
        }

        busy_count_cp: coverpoint sampled_busy_count {
            bins none      = {0};
            bins one       = {1};
            bins few       = {[2:4]};
            bins many      = {[5:16]};
        }

        stall_x_queue: cross stall_cp, queue_count_cp;
        stall_x_busy:  cross stall_cp, busy_count_cp;
    endgroup

    function new(string name = "qc_coverage", uvm_component parent = null);
        super.new(name, parent);
        observation_cg  = new();
        instruction_cg  = new();
        command_cg      = new();
        measurement_cg  = new();
        feedback_cg     = new();
        status_cg       = new();
    endfunction

    function void write(qc_observation_item t);
        sample_common(t);
        observation_cg.sample();

        case (t.kind)
            QC_OBS_INSTRUCTION,
            QC_OBS_ISSUE: begin
                instruction_samples++;
                instruction_cg.sample();

                if (t.kind == QC_OBS_ISSUE) begin
                    issue_samples++;
                end
            end

            QC_OBS_COMMAND: begin
                command_samples++;
                instruction_cg.sample();
                command_cg.sample();
            end

            QC_OBS_MEASURE_REQUEST,
            QC_OBS_MEASURE_RESPONSE,
            QC_OBS_MEASURE_RESULT: begin
                measurement_samples++;
                measurement_cg.sample();
            end

            QC_OBS_FEEDBACK: begin
                feedback_samples++;
                feedback_cg.sample();
            end

            QC_OBS_STATUS: begin
                status_samples++;
                status_cg.sample();
            end

            default: begin
                `uvm_warning(get_type_name(),
                             $sformatf("Coverage received unknown observation kind %0d",
                                       t.kind))
            end
        endcase
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);

        `uvm_info(get_type_name(),
                  $sformatf("Coverage samples: instruction=%0d issue=%0d command=%0d measurement=%0d feedback=%0d status=%0d",
                            instruction_samples,
                            issue_samples,
                            command_samples,
                            measurement_samples,
                            feedback_samples,
                            status_samples),
                  UVM_LOW)
    endfunction

    function void sample_common(qc_observation_item obs);
        sampled_kind                          = obs.kind;
        sampled_opcode                        = obs.opcode;
        sampled_valid_flag                    = obs.flags[FLAG_VALID_BIT];
        sampled_conditional_flag              = obs.flags[FLAG_CONDITIONAL_BIT];
        sampled_feedback_flag                 = obs.flags[FLAG_FEEDBACK_BIT];
        sampled_expected_flag                 = obs.flags[FLAG_EXPECTED_BIT];
        sampled_command_class                 = classify_command(obs);
        sampled_measure_request               = obs.measure_request_valid;
        sampled_measure_response              = obs.measurement_response_valid;
        sampled_measure_response_value        = obs.measurement_response_value;
        sampled_measure_result                = obs.measurement_result_valid;
        sampled_measure_result_value          = obs.measurement_result_value;
        sampled_measurement_busy              = obs.measurement_busy;
        sampled_unexpected_measurement_result = obs.unexpected_measurement_result;
        sampled_feedback_valid                = obs.feedback_valid;
        sampled_branch_taken                  = obs.branch_taken;
        sampled_condition_checked             = obs.condition_checked;
        sampled_missing_measurement           = obs.missing_measurement;
        sampled_feedback_value                = obs.feedback_value;
        sampled_scheduler_stall               = obs.scheduler_stall;
        sampled_illegal_instr                 = obs.illegal_instr;
        sampled_illegal_issue                 = obs.illegal_issue;
        sampled_queue_count                   = obs.queue_count;
        sampled_busy_count                    = count_busy_qubits(obs.qubit_busy);
    endfunction

    function qc_command_class_e classify_command(qc_observation_item obs);
        int unsigned class_count;

        class_count = int'(obs.gate_cmd) +
                      int'(obs.measure_cmd) +
                      int'(obs.wait_cmd) +
                      int'(obs.reset_cmd) +
                      int'(obs.branch_cmd) +
                      int'(obs.nop_cmd);

        if (class_count == 0) begin
            return QC_CMD_CLASS_NONE;
        end

        if (class_count > 1) begin
            return QC_CMD_CLASS_MULTI;
        end

        if (obs.gate_cmd) begin
            return QC_CMD_CLASS_GATE;
        end

        if (obs.measure_cmd) begin
            return QC_CMD_CLASS_MEASURE;
        end

        if (obs.wait_cmd) begin
            return QC_CMD_CLASS_WAIT;
        end

        if (obs.reset_cmd) begin
            return QC_CMD_CLASS_RESET;
        end

        if (obs.branch_cmd) begin
            return QC_CMD_CLASS_BRANCH;
        end

        return QC_CMD_CLASS_NOP;
    endfunction

    function int unsigned count_busy_qubits(logic [MAX_QUBITS-1:0] busy);
        int unsigned count;

        count = 0;
        for (int i = 0; i < MAX_QUBITS; i++) begin
            if (busy[i]) begin
                count++;
            end
        end

        return count;
    endfunction

endclass : qc_coverage

`endif
