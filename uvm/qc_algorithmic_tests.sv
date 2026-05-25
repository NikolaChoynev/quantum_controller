`ifndef QC_ALGORITHMIC_TESTS_SV
`define QC_ALGORITHMIC_TESTS_SV

class qc_bell_test extends qc_base_test;

    `uvm_component_utils(qc_bell_test)

    function new(string name = "qc_bell_test", uvm_component parent = null);
        super.new(name, parent);
        drain_cycles = 96;
    endfunction

    virtual task run_test_sequence();
        qc_algorithmic_bell_sequence seq;

        seq = qc_algorithmic_bell_sequence::type_id::create("seq");
        seq.start(env.agent.sequencer);
    endtask

endclass : qc_bell_test

class qc_ghz_test extends qc_base_test;

    `uvm_component_utils(qc_ghz_test)

    function new(string name = "qc_ghz_test", uvm_component parent = null);
        super.new(name, parent);
        drain_cycles = 128;
    endfunction

    virtual task run_test_sequence();
        qc_algorithmic_ghz_sequence seq;

        seq = qc_algorithmic_ghz_sequence::type_id::create("seq");
        seq.start(env.agent.sequencer);
    endtask

endclass : qc_ghz_test

class qc_grover_like_test extends qc_base_test;

    `uvm_component_utils(qc_grover_like_test)

    function new(string name = "qc_grover_like_test", uvm_component parent = null);
        super.new(name, parent);
        drain_cycles = 128;
    endfunction

    virtual task run_test_sequence();
        qc_algorithmic_grover_like_sequence seq;

        seq = qc_algorithmic_grover_like_sequence::type_id::create("seq");
        seq.start(env.agent.sequencer);
    endtask

endclass : qc_grover_like_test

class qc_random_circuit_sampling_test extends qc_base_test;

    int unsigned layer_count = 4;

    `uvm_component_utils(qc_random_circuit_sampling_test)

    function new(string name = "qc_random_circuit_sampling_test", uvm_component parent = null);
        super.new(name, parent);
        drain_cycles = 192;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        void'(uvm_config_db #(int unsigned)::get(
            this,
            "",
            "layer_count",
            layer_count
        ));
    endfunction

    virtual task run_test_sequence();
        qc_random_circuit_sampling_sequence seq;

        seq = qc_random_circuit_sampling_sequence::type_id::create("seq");
        seq.layer_count = layer_count;
        seq.start(env.agent.sequencer);
    endtask

endclass : qc_random_circuit_sampling_test

`endif
