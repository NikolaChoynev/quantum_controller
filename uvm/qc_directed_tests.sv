`ifndef QC_DIRECTED_TESTS_SV
`define QC_DIRECTED_TESTS_SV

class qc_smoke_test extends qc_base_test;

    `uvm_component_utils(qc_smoke_test)

    function new(string name = "qc_smoke_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_test_sequence();
        qc_smoke_sequence seq;

        seq = qc_smoke_sequence::type_id::create("seq");
        seq.start(env.agent.sequencer);
    endtask

endclass : qc_smoke_test

class qc_single_gate_test extends qc_base_test;

    `uvm_component_utils(qc_single_gate_test)

    function new(string name = "qc_single_gate_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_test_sequence();
        qc_single_gate_sequence seq;

        seq = qc_single_gate_sequence::type_id::create("seq");
        seq.start(env.agent.sequencer);
    endtask

endclass : qc_single_gate_test

class qc_cnot_test extends qc_base_test;

    `uvm_component_utils(qc_cnot_test)

    function new(string name = "qc_cnot_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_test_sequence();
        qc_cnot_sequence seq;

        seq = qc_cnot_sequence::type_id::create("seq");
        seq.start(env.agent.sequencer);
    endtask

endclass : qc_cnot_test

class qc_measure_test extends qc_base_test;

    `uvm_component_utils(qc_measure_test)

    function new(string name = "qc_measure_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_test_sequence();
        qc_measure_sequence seq;

        seq = qc_measure_sequence::type_id::create("seq");
        seq.start(env.agent.sequencer);
    endtask

endclass : qc_measure_test

class qc_wait_test extends qc_base_test;

    `uvm_component_utils(qc_wait_test)

    function new(string name = "qc_wait_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_test_sequence();
        qc_wait_sequence seq;

        seq = qc_wait_sequence::type_id::create("seq");
        seq.start(env.agent.sequencer);
    endtask

endclass : qc_wait_test

class qc_branch_test extends qc_base_test;

    `uvm_component_utils(qc_branch_test)

    function new(string name = "qc_branch_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_test_sequence();
        qc_branch_sequence seq;

        seq = qc_branch_sequence::type_id::create("seq");
        seq.start(env.agent.sequencer);
    endtask

endclass : qc_branch_test

class qc_invalid_opcode_test extends qc_base_test;

    `uvm_component_utils(qc_invalid_opcode_test)

    function new(string name = "qc_invalid_opcode_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual task run_test_sequence();
        qc_invalid_opcode_sequence seq;

        seq = qc_invalid_opcode_sequence::type_id::create("seq");
        seq.start(env.agent.sequencer);
    endtask

endclass : qc_invalid_opcode_test

`endif
