`timescale 1ns/1ps
package axi4lite_scoreboard_pkg;
    import uvm_pkg::*;
    import axi4lite_seq_item_pkg::*;
    `include "uvm_macros.svh"

    class axi4lite_scoreboard extends uvm_scoreboard;
        `uvm_component_utils(axi4lite_scoreboard)

        uvm_analysis_export #(axi4lite_seq_item)   sb_export;
        uvm_tlm_analysis_fifo #(axi4lite_seq_item) sb_fifo;
        axi4lite_seq_item item;

        // ---- reference model: mirrors the DUT's mem[] + addr_ok() exactly ----
        localparam NUM_WORDS   = 16;
        localparam RESP_OKAY   = 2'b00;
        localparam RESP_SLVERR = 2'b10;

        bit [31:0] shadow_mem [0:NUM_WORDS-1];

        int write_count, write_correct, write_error;
        int read_count,  read_correct,  read_error;
        int write_slverr_count, read_slverr_count;
        int resp_mismatch_count;

        function new(string name = "axi4lite_scoreboard", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            sb_export = new("sb_export", this);
            sb_fifo   = new("sb_fifo", this);
            write_count = 0; write_correct = 0; write_error = 0;
            read_count  = 0; read_correct  = 0; read_error  = 0;
            write_slverr_count = 0; read_slverr_count = 0;
            resp_mismatch_count = 0;
            for (int i = 0; i < NUM_WORDS; i++) shadow_mem[i] = 32'h0;
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            sb_export.connect(sb_fifo.analysis_export);
        endfunction

        // same rule as addr_ok() in axils.v: word-aligned AND in range
        function bit addr_ok(bit [31:0] byte_addr);
            return (byte_addr[1:0] == 2'b00) && (byte_addr < (NUM_WORDS * 4));
        endfunction

        task run_phase(uvm_phase phase);
            super.run_phase(phase);
            forever begin
                sb_fifo.get(item);

                if (item.rst) begin
                    for (int i = 0; i < NUM_WORDS; i++) shadow_mem[i] = 32'h0;
                    `uvm_info("SCOREBOARD", "reset observed, shadow memory cleared", UVM_HIGH)
                end

                if (item.write_done) begin
                    bit        ok;
                    bit [1:0]  exp_bresp;
                    int        idx;
                    write_count++;
                    ok        = addr_ok(item.awaddr);
                    exp_bresp = ok ? RESP_OKAY : RESP_SLVERR;

                    if (item.bresp !== exp_bresp) begin
                        `uvm_error("SCOREBOARD", $sformatf(
                            "BRESP mismatch addr=0x%0h got=%0b expected=%0b", item.awaddr, item.bresp, exp_bresp))
                        write_error++;
                        resp_mismatch_count++;
                    end
                    else begin
                        write_correct++;
                        if (!ok) write_slverr_count++;
                    end

                    // model the byte-strobe-preserving write, same as the DUT
                    if (ok) begin
                        idx = item.awaddr[5:2];
                        if (item.wstrb[0]) shadow_mem[idx][7:0]   = item.wdata[7:0];
                        if (item.wstrb[1]) shadow_mem[idx][15:8]  = item.wdata[15:8];
                        if (item.wstrb[2]) shadow_mem[idx][23:16] = item.wdata[23:16];
                        if (item.wstrb[3]) shadow_mem[idx][31:24] = item.wdata[31:24];
                    end
                end

                if (item.read_done) begin
                    bit        ok;
                    bit [1:0]  exp_rresp;
                    bit [31:0] exp_rdata;
                    int        idx;
                    read_count++;
                    ok        = addr_ok(item.araddr);
                    exp_rresp = ok ? RESP_OKAY : RESP_SLVERR;
                    idx       = item.araddr[5:2];
                    exp_rdata = ok ? shadow_mem[idx] : 32'h0;

                    if (item.rresp !== exp_rresp) begin
                        `uvm_error("SCOREBOARD", $sformatf(
                            "RRESP mismatch addr=0x%0h got=%0b expected=%0b", item.araddr, item.rresp, exp_rresp))
                        read_error++;
                        resp_mismatch_count++;
                    end
                    else if (item.rdata !== exp_rdata) begin
                        `uvm_error("SCOREBOARD", $sformatf(
                            "RDATA mismatch addr=0x%0h got=0x%0h expected=0x%0h", item.araddr, item.rdata, exp_rdata))
                        read_error++;
                    end
                    else begin
                        read_correct++;
                        if (!ok) read_slverr_count++;
                    end
                end
            end
        endtask

        function void report_phase(uvm_phase phase);
            super.report_phase(phase);
            `uvm_info("SUMMARY", "==========================================", UVM_NONE)
            `uvm_info("SUMMARY", "        AXI4-LITE SLAVE TEST RESULT", UVM_NONE)
            `uvm_info("SUMMARY", "==========================================", UVM_NONE)
            `uvm_info("SUMMARY", $sformatf("  Writes Issued        : %0d", write_count), UVM_NONE)
            `uvm_info("SUMMARY", $sformatf("  Writes Correct       : %0d", write_correct), UVM_NONE)
            `uvm_info("SUMMARY", $sformatf("  Writes Errored       : %0d", write_error), UVM_NONE)
            `uvm_info("SUMMARY", $sformatf("  Write SLVERR (exp)   : %0d", write_slverr_count), UVM_NONE)
            `uvm_info("SUMMARY", $sformatf("  Reads Issued         : %0d", read_count), UVM_NONE)
            `uvm_info("SUMMARY", $sformatf("  Reads Correct        : %0d", read_correct), UVM_NONE)
            `uvm_info("SUMMARY", $sformatf("  Reads Errored        : %0d", read_error), UVM_NONE)
            `uvm_info("SUMMARY", $sformatf("  Read SLVERR (exp)    : %0d", read_slverr_count), UVM_NONE)
            if (write_error == 0 && read_error == 0)
                `uvm_info("SUMMARY", "  RESULT               : ALL TESTS PASSED", UVM_NONE)
            else
                `uvm_error("SUMMARY", "  RESULT               : TEST FAILED")
            `uvm_info("SUMMARY", "==========================================", UVM_NONE)
        endfunction

    endclass
endpackage
