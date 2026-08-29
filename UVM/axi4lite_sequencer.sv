`timescale 1ns/1ps
package axi4lite_sequencer_pkg;
    import uvm_pkg::*;                       // built-in uvm_sequencer, no modifications needed.
    import axi4lite_seq_item_pkg::*;
    `include "uvm_macros.svh"                // uvm_sequencer already has seq_item_export built in.

    class axi4lite_sequencer extends uvm_sequencer #(axi4lite_seq_item);
        `uvm_component_utils(axi4lite_sequencer)

        function new(string name = "axi4lite_sequencer", uvm_component parent = null);
            super.new(name, parent);
        endfunction
    endclass

endpackage
