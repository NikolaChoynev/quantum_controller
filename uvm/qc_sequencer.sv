`ifndef QC_SEQUENCER_SV
`define QC_SEQUENCER_SV

class qc_sequencer extends uvm_sequencer #(qc_sequence_item);

    `uvm_component_utils(qc_sequencer)

    function new(string name = "qc_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction

endclass : qc_sequencer

`endif
