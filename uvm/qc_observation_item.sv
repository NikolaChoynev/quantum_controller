`ifndef QC_OBSERVATION_ITEM_SV
`define QC_OBSERVATION_ITEM_SV

typedef enum int unsigned {
    QC_OBS_INSTRUCTION,
    QC_OBS_ISSUE,
    QC_OBS_COMMAND,
    QC_OBS_MEASURE_REQUEST,
    QC_OBS_MEASURE_RESPONSE,
    QC_OBS_MEASURE_RESULT,
    QC_OBS_FEEDBACK,
    QC_OBS_STATUS
} qc_observation_kind_e;

class qc_observation_item extends uvm_sequence_item;

    qc_observation_kind_e       kind;

    logic [INSTR_W-1:0]         raw_instr;
    qc_opcode_e                 opcode;
    logic [QUBIT_ID_W-1:0]      target_qubit;
    logic [QUBIT_ID_W-1:0]      control_qubit;
    logic [DURATION_W-1:0]      duration;
    logic [FLAGS_W-1:0]         flags;
    logic [RESERVED_W-1:0]      reserved;

    bit                         gate_cmd;
    bit                         measure_cmd;
    bit                         wait_cmd;
    bit                         reset_cmd;
    bit                         branch_cmd;
    bit                         nop_cmd;

    bit                         measure_request_valid;
    logic [QUBIT_ID_W-1:0]      measure_qubit;
    bit                         measurement_busy;

    bit                         measurement_response_valid;
    bit                         measurement_response_value;

    bit                         measurement_result_valid;
    logic [QUBIT_ID_W-1:0]      measurement_result_qubit;
    bit                         measurement_result_value;
    logic [MAX_QUBITS-1:0]      measurement_valid;
    logic [MAX_QUBITS-1:0]      measurement_results;
    bit                         unexpected_measurement_result;

    bit                         feedback_valid;
    bit                         branch_taken;
    logic [DURATION_W-1:0]      branch_target;
    logic [QUBIT_ID_W-1:0]      feedback_qubit;
    bit                         feedback_value;
    bit                         condition_checked;
    bit                         missing_measurement;

    bit                         scheduler_stall;
    bit                         illegal_instr;
    bit                         illegal_issue;
    int unsigned                queue_count;
    logic [MAX_QUBITS-1:0]      qubit_busy;

    time                        sample_time;

    `uvm_object_utils_begin(qc_observation_item)
        `uvm_field_enum(qc_observation_kind_e, kind, UVM_DEFAULT)
        `uvm_field_int(raw_instr, UVM_DEFAULT)
        `uvm_field_enum(qc_opcode_e, opcode, UVM_DEFAULT)
        `uvm_field_int(target_qubit, UVM_DEFAULT)
        `uvm_field_int(control_qubit, UVM_DEFAULT)
        `uvm_field_int(duration, UVM_DEFAULT)
        `uvm_field_int(flags, UVM_DEFAULT)
        `uvm_field_int(reserved, UVM_DEFAULT)
        `uvm_field_int(gate_cmd, UVM_DEFAULT)
        `uvm_field_int(measure_cmd, UVM_DEFAULT)
        `uvm_field_int(wait_cmd, UVM_DEFAULT)
        `uvm_field_int(reset_cmd, UVM_DEFAULT)
        `uvm_field_int(branch_cmd, UVM_DEFAULT)
        `uvm_field_int(nop_cmd, UVM_DEFAULT)
        `uvm_field_int(measure_request_valid, UVM_DEFAULT)
        `uvm_field_int(measure_qubit, UVM_DEFAULT)
        `uvm_field_int(measurement_busy, UVM_DEFAULT)
        `uvm_field_int(measurement_response_valid, UVM_DEFAULT)
        `uvm_field_int(measurement_response_value, UVM_DEFAULT)
        `uvm_field_int(measurement_result_valid, UVM_DEFAULT)
        `uvm_field_int(measurement_result_qubit, UVM_DEFAULT)
        `uvm_field_int(measurement_result_value, UVM_DEFAULT)
        `uvm_field_int(measurement_valid, UVM_DEFAULT)
        `uvm_field_int(measurement_results, UVM_DEFAULT)
        `uvm_field_int(unexpected_measurement_result, UVM_DEFAULT)
        `uvm_field_int(feedback_valid, UVM_DEFAULT)
        `uvm_field_int(branch_taken, UVM_DEFAULT)
        `uvm_field_int(branch_target, UVM_DEFAULT)
        `uvm_field_int(feedback_qubit, UVM_DEFAULT)
        `uvm_field_int(feedback_value, UVM_DEFAULT)
        `uvm_field_int(condition_checked, UVM_DEFAULT)
        `uvm_field_int(missing_measurement, UVM_DEFAULT)
        `uvm_field_int(scheduler_stall, UVM_DEFAULT)
        `uvm_field_int(illegal_instr, UVM_DEFAULT)
        `uvm_field_int(illegal_issue, UVM_DEFAULT)
        `uvm_field_int(queue_count, UVM_DEFAULT)
        `uvm_field_int(qubit_busy, UVM_DEFAULT)
        `uvm_field_int(sample_time, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "qc_observation_item");
        super.new(name);
        clear();
    endfunction

    function void clear();
        kind                         = QC_OBS_STATUS;
        raw_instr                    = '0;
        opcode                       = OP_NOP;
        target_qubit                 = '0;
        control_qubit                = '0;
        duration                     = '0;
        flags                        = '0;
        reserved                     = '0;
        gate_cmd                     = 1'b0;
        measure_cmd                  = 1'b0;
        wait_cmd                     = 1'b0;
        reset_cmd                    = 1'b0;
        branch_cmd                   = 1'b0;
        nop_cmd                      = 1'b0;
        measure_request_valid        = 1'b0;
        measure_qubit                = '0;
        measurement_busy             = 1'b0;
        measurement_response_valid   = 1'b0;
        measurement_response_value   = 1'b0;
        measurement_result_valid     = 1'b0;
        measurement_result_qubit     = '0;
        measurement_result_value     = 1'b0;
        measurement_valid            = '0;
        measurement_results          = '0;
        unexpected_measurement_result = 1'b0;
        feedback_valid               = 1'b0;
        branch_taken                 = 1'b0;
        branch_target                = '0;
        feedback_qubit               = '0;
        feedback_value               = 1'b0;
        condition_checked            = 1'b0;
        missing_measurement          = 1'b0;
        scheduler_stall              = 1'b0;
        illegal_instr                = 1'b0;
        illegal_issue                = 1'b0;
        queue_count                  = 0;
        qubit_busy                   = '0;
        sample_time                  = 0;
    endfunction

    function void load_raw(input logic [INSTR_W-1:0] raw);
        qc_instr_t decoded;

        decoded.raw = raw;

        raw_instr     = raw;
        opcode        = decoded.fields.opcode;
        target_qubit  = decoded.fields.target_qubit;
        control_qubit = decoded.fields.control_qubit;
        duration      = decoded.fields.duration;
        flags         = decoded.fields.flags;
        reserved      = decoded.fields.reserved;
    endfunction

    function void load_fields(
        input qc_opcode_e opcode_i,
        input logic [QUBIT_ID_W-1:0] target_qubit_i,
        input logic [QUBIT_ID_W-1:0] control_qubit_i,
        input logic [DURATION_W-1:0] duration_i,
        input logic [FLAGS_W-1:0] flags_i
    );
        opcode        = opcode_i;
        target_qubit  = target_qubit_i;
        control_qubit = control_qubit_i;
        duration      = duration_i;
        flags         = flags_i;
        reserved      = '0;
        raw_instr     = {
            opcode_i,
            target_qubit_i,
            control_qubit_i,
            duration_i,
            flags_i,
            {RESERVED_W{1'b0}}
        };
    endfunction

    function string convert2string();
        return $sformatf(
            "kind=%s time=%0t raw=0x%08h opcode=%s target=%0d control=%0d duration=%0d flags=0x%0h cmd={g:%0b m:%0b w:%0b r:%0b b:%0b n:%0b} meas={req:%0b q:%0d resp:%0b/%0b out:%0b q:%0d val:%0b} feedback={valid:%0b taken:%0b target:%0d missing:%0b} status={stall:%0b illegal_instr:%0b illegal_issue:%0b unexpected_meas:%0b qcnt:%0d busy:0x%0h}",
            kind.name(),
            sample_time,
            raw_instr,
            opcode.name(),
            target_qubit,
            control_qubit,
            duration,
            flags,
            gate_cmd,
            measure_cmd,
            wait_cmd,
            reset_cmd,
            branch_cmd,
            nop_cmd,
            measure_request_valid,
            measure_qubit,
            measurement_response_valid,
            measurement_response_value,
            measurement_result_valid,
            measurement_result_qubit,
            measurement_result_value,
            feedback_valid,
            branch_taken,
            branch_target,
            missing_measurement,
            scheduler_stall,
            illegal_instr,
            illegal_issue,
            unexpected_measurement_result,
            queue_count,
            qubit_busy
        );
    endfunction

endclass : qc_observation_item

`endif
