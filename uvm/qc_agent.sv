`ifndef QC_AGENT_SV
`define QC_AGENT_SV

class qc_agent extends uvm_agent;

    qc_sequencer sequencer;
    qc_driver    driver;
    qc_monitor   monitor;

    virtual qc_if vif;
    bit           has_vif;

    `uvm_component_utils(qc_agent)

    function new(string name = "qc_agent", uvm_component parent = null);
        super.new(name, parent);
        is_active = UVM_ACTIVE;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        void'(uvm_config_db #(uvm_active_passive_enum)::get(
            this,
            "",
            "is_active",
            is_active
        ));

        has_vif = uvm_config_db #(virtual qc_if)::get(this, "", "vif", vif);

        if (has_vif) begin
            uvm_config_db #(virtual qc_if)::set(this, "monitor", "vif", vif);

            if (is_active == UVM_ACTIVE) begin
                uvm_config_db #(virtual qc_if)::set(this, "driver", "vif", vif);
            end
        end

        monitor = qc_monitor::type_id::create("monitor", this);

        if (is_active == UVM_ACTIVE) begin
            sequencer = qc_sequencer::type_id::create("sequencer", this);
            driver    = qc_driver::type_id::create("driver", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        if (is_active == UVM_ACTIVE) begin
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end
    endfunction

endclass : qc_agent

`endif
