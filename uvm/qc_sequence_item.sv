`ifndef QC_SEQUENCE_ITEM_SV
`define QC_SEQUENCE_ITEM_SV

class qc_sequence_item extends uvm_sequence_item;

    rand qc_opcode_e            opcode;
    rand logic [QUBIT_ID_W-1:0] target_qubit;
    rand logic [QUBIT_ID_W-1:0] control_qubit;
    rand logic [DURATION_W-1:0] duration;
    rand logic [FLAGS_W-1:0]    flags;
    rand logic [RESERVED_W-1:0] reserved;

    rand bit                    valid_instruction;
    rand bit                    allow_invalid_opcode;
    rand bit                    raw_override_en;
    rand logic [INSTR_W-1:0]    raw_override_value;

    rand bit                    send_measurement_result;
    rand bit                    measurement_result_value;
    rand int unsigned           measurement_latency_cycles;

    logic [INSTR_W-1:0]         raw_instr;

    constraint defaults_c {
        soft valid_instruction      == 1'b1;
        soft allow_invalid_opcode   == 1'b0;
        soft raw_override_en        == 1'b0;
        soft reserved               == '0;
    }

    constraint opcode_c {
        (raw_override_en == 1'b0 && allow_invalid_opcode == 1'b0) ->
            opcode inside {
                OP_NOP,
                OP_H,
                OP_X,
                OP_Z,
                OP_CNOT,
                OP_MEASURE,
                OP_WAIT,
                OP_RESET,
                OP_BRANCH
            };
    }

    constraint flags_c {
        (raw_override_en == 1'b0) ->
            flags[FLAG_VALID_BIT] == valid_instruction;
    }

    constraint cnot_qubits_c {
        (raw_override_en == 1'b0 && opcode == OP_CNOT) ->
            target_qubit != control_qubit;
    }

    constraint wait_duration_c {
        (raw_override_en == 1'b0 && opcode == OP_WAIT) ->
            duration > 0;
    }

    constraint measurement_response_c {
        (opcode != OP_MEASURE) -> (send_measurement_result == 1'b0);
        (send_measurement_result == 1'b1) -> (opcode == OP_MEASURE);
        measurement_latency_cycles inside {[1:64]};
    }

    `uvm_object_utils_begin(qc_sequence_item)
        `uvm_field_enum(qc_opcode_e, opcode, UVM_DEFAULT)
        `uvm_field_int(target_qubit, UVM_DEFAULT)
        `uvm_field_int(control_qubit, UVM_DEFAULT)
        `uvm_field_int(duration, UVM_DEFAULT)
        `uvm_field_int(flags, UVM_DEFAULT)
        `uvm_field_int(reserved, UVM_DEFAULT)
        `uvm_field_int(valid_instruction, UVM_DEFAULT)
        `uvm_field_int(allow_invalid_opcode, UVM_DEFAULT)
        `uvm_field_int(raw_override_en, UVM_DEFAULT)
        `uvm_field_int(raw_override_value, UVM_DEFAULT)
        `uvm_field_int(send_measurement_result, UVM_DEFAULT)
        `uvm_field_int(measurement_result_value, UVM_DEFAULT)
        `uvm_field_int(measurement_latency_cycles, UVM_DEFAULT)
        `uvm_field_int(raw_instr, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "qc_sequence_item");
        super.new(name);
    endfunction

    function void post_randomize();
        update_raw();
    endfunction

    function logic [INSTR_W-1:0] pack_raw();
        if (raw_override_en) begin
            return raw_override_value;
        end

        return {
            opcode,
            target_qubit,
            control_qubit,
            duration,
            flags,
            reserved
        };
    endfunction

    function void update_raw();
        raw_instr = pack_raw();
    endfunction

    function void load_raw(input logic [INSTR_W-1:0] raw);
        qc_instr_t decoded;

        decoded.raw = raw;

        opcode              = decoded.fields.opcode;
        target_qubit        = decoded.fields.target_qubit;
        control_qubit       = decoded.fields.control_qubit;
        duration            = decoded.fields.duration;
        flags               = decoded.fields.flags;
        reserved            = decoded.fields.reserved;
        valid_instruction   = decoded.fields.flags[FLAG_VALID_BIT];
        raw_override_en     = 1'b1;
        raw_override_value  = raw;
        raw_instr           = raw;
    endfunction

    function qc_instr_fields_t to_fields();
        qc_instr_fields_t fields;

        fields.opcode        = opcode;
        fields.target_qubit  = target_qubit;
        fields.control_qubit = control_qubit;
        fields.duration      = duration;
        fields.flags         = flags;
        fields.reserved      = reserved;

        return fields;
    endfunction

    function bit is_valid_instruction();
        return flags[FLAG_VALID_BIT];
    endfunction

    function bit is_gate_instruction();
        return opcode inside {OP_H, OP_X, OP_Z, OP_CNOT};
    endfunction

    function bit uses_control_qubit();
        return opcode == OP_CNOT;
    endfunction

    function bit is_measurement_instruction();
        return opcode == OP_MEASURE;
    endfunction

    function bit is_branch_instruction();
        return opcode == OP_BRANCH;
    endfunction

    function string convert2string();
        logic [INSTR_W-1:0] display_raw;

        display_raw = pack_raw();

        return $sformatf(
            "raw=0x%08h opcode=%s target=%0d control=%0d duration=%0d flags=0x%0h measurement_response=%0b latency=%0d value=%0b",
            display_raw,
            opcode.name(),
            target_qubit,
            control_qubit,
            duration,
            flags,
            send_measurement_result,
            measurement_latency_cycles,
            measurement_result_value
        );
    endfunction

endclass : qc_sequence_item

`endif
