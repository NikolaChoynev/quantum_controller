`ifndef QC_BASE_TEST_SV
`define QC_BASE_TEST_SV

class qc_base_test extends uvm_test;

    qc_env        env;
    virtual qc_if vif;

    int unsigned drain_cycles = 64;

    `uvm_component_utils(qc_base_test)

    function new(string name = "qc_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        void'(uvm_config_db #(int unsigned)::get(
            this,
            "",
            "drain_cycles",
            drain_cycles
        ));

        if (!uvm_config_db #(virtual qc_if)::get(this, "", "vif", vif)) begin
            `uvm_fatal(get_type_name(), "Virtual interface 'vif' was not provided")
        end

        uvm_config_db #(virtual qc_if)::set(this, "env.agent", "vif", vif);

        env = qc_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        run_test_sequence();
        drain_pipeline();

        phase.drop_objection(this);
    endtask

    virtual task run_test_sequence();
        `uvm_info(get_type_name(), "Base test has no default sequence", UVM_LOW)
    endtask

    task drain_pipeline();
        repeat (drain_cycles) begin
            @(posedge vif.clk_i);
        end
    endtask

endclass : qc_base_test

`endif
