`ifndef QC_RANDOM_TESTS_SV
`define QC_RANDOM_TESTS_SV

class qc_random_test extends qc_base_test;

    int unsigned item_count = 48;

    `uvm_component_utils(qc_random_test)

    function new(string name = "qc_random_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        void'(uvm_config_db #(int unsigned)::get(
            this,
            "",
            "item_count",
            item_count
        ));
    endfunction

    virtual task run_test_sequence();
        qc_random_instruction_sequence seq;

        seq = qc_random_instruction_sequence::type_id::create("seq");
        seq.item_count = item_count;
        seq.start(env.agent.sequencer);
    endtask

endclass : qc_random_test

class qc_dependency_stress_test extends qc_base_test;

    `uvm_component_utils(qc_dependency_stress_test)

    function new(string name = "qc_dependency_stress_test", uvm_component parent = null);
        super.new(name, parent);
        drain_cycles = 96;
    endfunction

    virtual task run_test_sequence();
        qc_dependency_stress_sequence seq;

        seq = qc_dependency_stress_sequence::type_id::create("seq");
        seq.start(env.agent.sequencer);
    endtask

endclass : qc_dependency_stress_test

class qc_hazard_test extends qc_base_test;

    `uvm_component_utils(qc_hazard_test)

    function new(string name = "qc_hazard_test", uvm_component parent = null);
        super.new(name, parent);
        drain_cycles = 128;
    endfunction

    virtual task run_test_sequence();
        qc_hazard_sequence seq;

        seq = qc_hazard_sequence::type_id::create("seq");
        seq.start(env.agent.sequencer);
    endtask

endclass : qc_hazard_test

class qc_queue_overflow_test extends qc_base_test;

    int unsigned burst_count = 10;

    `uvm_component_utils(qc_queue_overflow_test)

    function new(string name = "qc_queue_overflow_test", uvm_component parent = null);
        super.new(name, parent);
        drain_cycles = 160;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        void'(uvm_config_db #(int unsigned)::get(
            this,
            "",
            "burst_count",
            burst_count
        ));
    endfunction

    virtual task run_test_sequence();
        qc_queue_overflow_sequence seq;

        seq = qc_queue_overflow_sequence::type_id::create("seq");
        seq.burst_count = burst_count;
        seq.start(env.agent.sequencer);
    endtask

endclass : qc_queue_overflow_test

`endif
