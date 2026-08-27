`timescale 1ns/1ps
package axi4lite_config_obj_pkg;      // holds parameters + the interface handle so every
    import uvm_pkg::*;            // component (driver, monitor, scoreboard, ...) shares the same view
    `include "uvm_macros.svh"

    class axi4lite_config_obj extends uvm_object;
        `uvm_object_utils(axi4lite_config_obj)

        virtual axi4lite_if axi4lite_vif;

        int num_words = 16;                 // must match NUM_WORDS localparam in axils.v
        int addr_hi_bit = 5;                // NUM_WORDS*4 = 64B -> addr[5:2] is the word index

        function new(string name = "axi4lite_config_obj");
            super.new(name);
        endfunction

        function int mem_bytes();
            return num_words * 4;
        endfunction

    endclass
endpackage
