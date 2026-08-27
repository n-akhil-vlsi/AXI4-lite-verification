`timescale 1ns/1ps
package axi4lite_coverage_pkg;

    import uvm_pkg::*;
    import axi4lite_seq_item_pkg::*;
    `include "uvm_macros.svh"

    class axi4lite_coverage extends uvm_subscriber #(axi4lite_seq_item);
        `uvm_component_utils(axi4lite_coverage)          // axi4lite_coverage is a component
        axi4lite_seq_item item;

        localparam NUM_WORDS = 16;

        covergroup cg;
            option.per_instance = 1;                 // coverage kept separate per instance

            cp_write_done : coverpoint item.write_done;
            cp_read_done  : coverpoint item.read_done;

            cp_bresp : coverpoint item.bresp {
                bins okay   = {2'b00};
                bins slverr = {2'b10};
            }
            cp_rresp : coverpoint item.rresp {
                bins okay   = {2'b00};
                bins slverr = {2'b10};
            }

            cp_waddr_word : coverpoint (item.awaddr[5:2]) iff (item.write_done && item.bresp == 2'b00) {
                bins word[NUM_WORDS] = {[0:NUM_WORDS-1]};
            }
            cp_raddr_word : coverpoint (item.araddr[5:2]) iff (item.read_done && item.rresp == 2'b00) {
                bins word[NUM_WORDS] = {[0:NUM_WORDS-1]};
            }

            cp_wstrb : coverpoint item.wstrb iff (item.write_done) {
                bins all_bytes  = {4'b1111};
                bins lower_half = {4'b0011};
                bins upper_half = {4'b1100};
                bins byte0      = {4'b0001};
                bins byte1      = {4'b0010};
                bins byte2      = {4'b0100};
                bins byte3      = {4'b1000};
                bins others     = default;
            }

            // simultaneous write+read completing in the same coverage sample
            cross cp_write_done, cp_read_done;

            // both response types cross both channels, so a SLVERR on one
            // channel while the other channel returns OKAY gets covered
            cross cp_bresp, cp_rresp;

        endgroup

        function new(string name = "axi4lite_coverage", uvm_component parent = null);
            super.new(name, parent);
            cg = new();
            `uvm_info("COV", "Covergroup Created", UVM_NONE)
        endfunction

        function void write(axi4lite_seq_item t);
            item = t;
            `uvm_info("COV", $sformatf(
                "WR=%0d RD=%0d BRESP=%0b RRESP=%0b AWADDR=0x%0h ARADDR=0x%0h WSTRB=%0b",
                item.write_done, item.read_done, item.bresp, item.rresp,
                item.awaddr, item.araddr, item.wstrb), UVM_HIGH)

            cg.sample();

            `uvm_info("COV", $sformatf("Current Functional Coverage = %0.2f%%", cg.get_inst_coverage()), UVM_HIGH)
        endfunction

        function void report_phase(uvm_phase phase);
            super.report_phase(phase);
            `uvm_info("COV", $sformatf("FINAL FUNCTIONAL COVERAGE = %0.2f%%", cg.get_inst_coverage()), UVM_NONE)
        endfunction

    endclass

endpackage
