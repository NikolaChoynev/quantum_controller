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

`endif
