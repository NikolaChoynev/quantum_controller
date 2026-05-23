`timescale 1ns/1ps

`ifndef QC_UVM_PKG_SV
`define QC_UVM_PKG_SV

package qc_uvm_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    import qc_pkg::*;

    `include "qc_sequence_item.sv"
    `include "qc_sequencer.sv"
    `include "qc_sequences.sv"
    `include "qc_driver.sv"

endpackage : qc_uvm_pkg

`endif
