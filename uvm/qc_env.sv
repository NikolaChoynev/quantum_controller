`ifndef QC_ENV_SV
`define QC_ENV_SV

class qc_env extends uvm_env;

    qc_agent      agent;
    qc_scoreboard scoreboard;
    qc_coverage   coverage;

    bit enable_scoreboard = 1'b1;
    bit enable_coverage   = 1'b1;

    `uvm_component_utils(qc_env)

    function new(string name = "qc_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        void'(uvm_config_db #(bit)::get(
            this,
            "",
            "enable_scoreboard",
            enable_scoreboard
        ));

        void'(uvm_config_db #(bit)::get(
            this,
            "",
            "enable_coverage",
            enable_coverage
        ));

        agent = qc_agent::type_id::create("agent", this);

        if (enable_scoreboard) begin
            scoreboard = qc_scoreboard::type_id::create("scoreboard", this);
        end

        if (enable_coverage) begin
            coverage = qc_coverage::type_id::create("coverage", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        if (enable_scoreboard) begin
            agent.monitor.analysis_port.connect(scoreboard.analysis_export);
        end

        if (enable_coverage) begin
            agent.monitor.analysis_port.connect(coverage.analysis_export);
        end
    endfunction

endclass : qc_env

`endif
