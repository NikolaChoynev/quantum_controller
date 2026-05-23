`ifndef QC_SEQUENCES_SV
`define QC_SEQUENCES_SV

class qc_base_sequence extends uvm_sequence #(qc_sequence_item);

    `uvm_object_utils(qc_base_sequence)

    function new(string name = "qc_base_sequence");
        super.new(name);
    endfunction

    function automatic logic [FLAGS_W-1:0] make_flags(
        input bit valid       = 1'b1,
        input bit conditional = 1'b0,
        input bit feedback    = 1'b0,
        input bit expected    = 1'b0
    );
        logic [FLAGS_W-1:0] flags;

        flags = '0;
        flags[FLAG_VALID_BIT]       = valid;
        flags[FLAG_CONDITIONAL_BIT] = conditional;
        flags[FLAG_FEEDBACK_BIT]    = feedback;
        flags[FLAG_EXPECTED_BIT]    = expected;

        return flags;
    endfunction

    virtual task send_instruction(
        input qc_opcode_e opcode_i,
        input logic [QUBIT_ID_W-1:0] target_qubit_i  = '0,
        input logic [QUBIT_ID_W-1:0] control_qubit_i = '0,
        input logic [DURATION_W-1:0] duration_i      = 12'd1,
        input logic [FLAGS_W-1:0] flags_i            = (1'b1 << FLAG_VALID_BIT),
        input logic [RESERVED_W-1:0] reserved_i      = '0,
        input bit send_measurement_result_i          = 1'b0,
        input bit measurement_result_value_i         = 1'b0,
        input int unsigned measurement_latency_i     = 3
    );
        qc_sequence_item item;

        item = qc_sequence_item::type_id::create("item");

        item.opcode                     = opcode_i;
        item.target_qubit               = target_qubit_i;
        item.control_qubit              = control_qubit_i;
        item.duration                   = duration_i;
        item.flags                      = flags_i;
        item.reserved                   = reserved_i;
        item.valid_instruction          = flags_i[FLAG_VALID_BIT];
        item.allow_invalid_opcode       = 1'b0;
        item.raw_override_en            = 1'b0;
        item.raw_override_value         = '0;
        item.send_measurement_result    = send_measurement_result_i;
        item.measurement_result_value   = measurement_result_value_i;
        item.measurement_latency_cycles = measurement_latency_i;
        item.update_raw();

        start_item(item);
        finish_item(item);

        `uvm_info(get_type_name(), item.convert2string(), UVM_MEDIUM)
    endtask

    virtual task send_raw_instruction(
        input logic [INSTR_W-1:0] raw_instr_i,
        input bit send_measurement_result_i      = 1'b0,
        input bit measurement_result_value_i     = 1'b0,
        input int unsigned measurement_latency_i = 3
    );
        qc_sequence_item item;

        item = qc_sequence_item::type_id::create("raw_item");
        item.load_raw(raw_instr_i);
        item.send_measurement_result    = send_measurement_result_i;
        item.measurement_result_value   = measurement_result_value_i;
        item.measurement_latency_cycles = measurement_latency_i;

        start_item(item);
        finish_item(item);

        `uvm_info(get_type_name(), item.convert2string(), UVM_MEDIUM)
    endtask

    virtual task body();
        `uvm_info(get_type_name(), "Base sequence has no default stimulus", UVM_LOW)
    endtask

endclass : qc_base_sequence

class qc_smoke_sequence extends qc_base_sequence;

    `uvm_object_utils(qc_smoke_sequence)

    function new(string name = "qc_smoke_sequence");
        super.new(name);
    endfunction

    virtual task body();
        send_instruction(OP_H,       4'd0, 4'd0, 12'd4,  make_flags());
        send_instruction(OP_MEASURE, 4'd0, 4'd0, 12'd6,  make_flags(), '0, 1'b1, 1'b1, 3);
        send_instruction(OP_BRANCH,  4'd0, 4'd0, 12'd16, make_flags(1'b1, 1'b1, 1'b1, 1'b1));
    endtask

endclass : qc_smoke_sequence

class qc_single_gate_sequence extends qc_base_sequence;

    `uvm_object_utils(qc_single_gate_sequence)

    function new(string name = "qc_single_gate_sequence");
        super.new(name);
    endfunction

    virtual task body();
        send_instruction(OP_H, 4'd0, 4'd0, 12'd4, make_flags());
        send_instruction(OP_X, 4'd1, 4'd0, 12'd4, make_flags());
        send_instruction(OP_Z, 4'd2, 4'd0, 12'd4, make_flags());
    endtask

endclass : qc_single_gate_sequence

class qc_cnot_sequence extends qc_base_sequence;

    `uvm_object_utils(qc_cnot_sequence)

    function new(string name = "qc_cnot_sequence");
        super.new(name);
    endfunction

    virtual task body();
        send_instruction(OP_H,    4'd0, 4'd0, 12'd4, make_flags());
        send_instruction(OP_CNOT, 4'd1, 4'd0, 12'd8, make_flags());
    endtask

endclass : qc_cnot_sequence

class qc_measure_sequence extends qc_base_sequence;

    `uvm_object_utils(qc_measure_sequence)

    function new(string name = "qc_measure_sequence");
        super.new(name);
    endfunction

    virtual task body();
        send_instruction(OP_MEASURE, 4'd3, 4'd0, 12'd6, make_flags(), '0, 1'b1, 1'b1, 4);
    endtask

endclass : qc_measure_sequence

class qc_wait_sequence extends qc_base_sequence;

    `uvm_object_utils(qc_wait_sequence)

    function new(string name = "qc_wait_sequence");
        super.new(name);
    endfunction

    virtual task body();
        send_instruction(OP_H,    4'd0, 4'd0, 12'd4, make_flags());
        send_instruction(OP_WAIT, 4'd0, 4'd0, 12'd5, make_flags());
        send_instruction(OP_X,    4'd1, 4'd0, 12'd4, make_flags());
    endtask

endclass : qc_wait_sequence

class qc_branch_sequence extends qc_base_sequence;

    `uvm_object_utils(qc_branch_sequence)

    function new(string name = "qc_branch_sequence");
        super.new(name);
    endfunction

    virtual task body();
        send_instruction(OP_MEASURE, 4'd2, 4'd0, 12'd6,  make_flags(), '0, 1'b1, 1'b1, 3);
        send_instruction(OP_BRANCH,  4'd2, 4'd0, 12'd24, make_flags(1'b1, 1'b1, 1'b1, 1'b1));
        send_instruction(OP_X,       4'd4, 4'd0, 12'd4,  make_flags());
    endtask

endclass : qc_branch_sequence

class qc_invalid_opcode_sequence extends qc_base_sequence;

    `uvm_object_utils(qc_invalid_opcode_sequence)

    function new(string name = "qc_invalid_opcode_sequence");
        super.new(name);
    endfunction

    virtual task body();
        send_raw_instruction({4'hE, 4'd0, 4'd0, 12'd0, make_flags(), 4'd0});
    endtask

endclass : qc_invalid_opcode_sequence

class qc_random_instruction_sequence extends qc_base_sequence;

    rand int unsigned item_count;

    constraint item_count_c {
        item_count inside {[16:64]};
    }

    `uvm_object_utils_begin(qc_random_instruction_sequence)
        `uvm_field_int(item_count, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "qc_random_instruction_sequence");
        super.new(name);
    endfunction

    virtual task body();
        qc_sequence_item item;

        if (item_count == 0) begin
            item_count = 32;
        end

        repeat (item_count) begin
            item = qc_sequence_item::type_id::create("random_item");

            start_item(item);
            if (!item.randomize() with {
                raw_override_en == 1'b0;
                allow_invalid_opcode == 1'b0;
                valid_instruction == 1'b1;
            }) begin
                `uvm_error(get_type_name(), "Failed to randomize qc_sequence_item")
            end
            finish_item(item);

            `uvm_info(get_type_name(), item.convert2string(), UVM_HIGH)
        end
    endtask

endclass : qc_random_instruction_sequence

class qc_dependency_stress_sequence extends qc_base_sequence;

    `uvm_object_utils(qc_dependency_stress_sequence)

    function new(string name = "qc_dependency_stress_sequence");
        super.new(name);
    endfunction

    virtual task body();
        send_instruction(OP_H,    4'd0, 4'd0, 12'd5, make_flags());
        send_instruction(OP_X,    4'd0, 4'd0, 12'd3, make_flags());
        send_instruction(OP_Z,    4'd0, 4'd0, 12'd2, make_flags());
        send_instruction(OP_CNOT, 4'd1, 4'd0, 12'd6, make_flags());
        send_instruction(OP_CNOT, 4'd2, 4'd0, 12'd6, make_flags());
        send_instruction(OP_H,    4'd3, 4'd0, 12'd2, make_flags());
    endtask

endclass : qc_dependency_stress_sequence

class qc_algorithmic_bell_sequence extends qc_base_sequence;

    `uvm_object_utils(qc_algorithmic_bell_sequence)

    function new(string name = "qc_algorithmic_bell_sequence");
        super.new(name);
    endfunction

    virtual task body();
        send_instruction(OP_H,       4'd0, 4'd0, 12'd4, make_flags());
        send_instruction(OP_CNOT,    4'd1, 4'd0, 12'd8, make_flags());
        send_instruction(OP_MEASURE, 4'd0, 4'd0, 12'd6, make_flags(), '0, 1'b1, 1'b0, 3);
        send_instruction(OP_MEASURE, 4'd1, 4'd0, 12'd6, make_flags(), '0, 1'b1, 1'b0, 3);
    endtask

endclass : qc_algorithmic_bell_sequence

class qc_algorithmic_ghz_sequence extends qc_base_sequence;

    `uvm_object_utils(qc_algorithmic_ghz_sequence)

    function new(string name = "qc_algorithmic_ghz_sequence");
        super.new(name);
    endfunction

    virtual task body();
        send_instruction(OP_H,       4'd0, 4'd0, 12'd4, make_flags());
        send_instruction(OP_CNOT,    4'd1, 4'd0, 12'd8, make_flags());
        send_instruction(OP_CNOT,    4'd2, 4'd1, 12'd8, make_flags());
        send_instruction(OP_MEASURE, 4'd0, 4'd0, 12'd6, make_flags(), '0, 1'b1, 1'b1, 3);
        send_instruction(OP_MEASURE, 4'd1, 4'd0, 12'd6, make_flags(), '0, 1'b1, 1'b1, 3);
        send_instruction(OP_MEASURE, 4'd2, 4'd0, 12'd6, make_flags(), '0, 1'b1, 1'b1, 3);
    endtask

endclass : qc_algorithmic_ghz_sequence

class qc_algorithmic_grover_like_sequence extends qc_base_sequence;

    `uvm_object_utils(qc_algorithmic_grover_like_sequence)

    function new(string name = "qc_algorithmic_grover_like_sequence");
        super.new(name);
    endfunction

    virtual task body();
        send_instruction(OP_H,       4'd0, 4'd0, 12'd4,  make_flags());
        send_instruction(OP_H,       4'd1, 4'd0, 12'd4,  make_flags());
        send_instruction(OP_X,       4'd1, 4'd0, 12'd4,  make_flags());
        send_instruction(OP_CNOT,    4'd1, 4'd0, 12'd8,  make_flags());
        send_instruction(OP_Z,       4'd1, 4'd0, 12'd4,  make_flags());
        send_instruction(OP_MEASURE, 4'd1, 4'd0, 12'd6,  make_flags(), '0, 1'b1, 1'b1, 4);
        send_instruction(OP_BRANCH,  4'd1, 4'd0, 12'd32, make_flags(1'b1, 1'b1, 1'b1, 1'b1));
    endtask

endclass : qc_algorithmic_grover_like_sequence

`endif
