`timescale 1ns/1ps
package axi4lite_monitor_pkg;
    import uvm_pkg::*;
    import axi4lite_seq_item_pkg::*;
    import axi4lite_config_obj_pkg::*;
    `include "uvm_macros.svh"

    class axi4lite_monitor extends uvm_monitor;
        `uvm_component_utils(axi4lite_monitor)

        virtual axi4lite_if  vif;                  // set in the agent (mon.vif = cfg.axi4lite_vif)
        axi4lite_config_obj  cfg;

        uvm_analysis_port #(axi4lite_seq_item) mon_ap;
        // TLM connection used to forward observed transactions to the scoreboard/coverage

        // AW and W can complete their handshakes on different cycles, so each
        // side is queued independently and paired up only when BVALID fires -
        // avoids any race on which one "arrived last".
        bit [31:0] awaddr_q[$];
        bit [31:0] wdata_q[$];
        bit [3:0]  wstrb_q[$];
        bit [31:0] araddr_q[$];

        function new(string name = "axi4lite_monitor", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            mon_ap = new("mon_ap", this);
            if (!uvm_config_db#(axi4lite_config_obj)::get(this, "", "CFG", cfg))
                `uvm_fatal("build_phase", "monitor could not get config object")
        endfunction

        task watch_aw();
            forever begin
                @(posedge vif.aclk);
                if (vif.awvalid && vif.awready)
                    awaddr_q.push_back(vif.awaddr);
            end
        endtask

        task watch_w();
            forever begin
                @(posedge vif.aclk);
                if (vif.wvalid && vif.wready) begin
                    wdata_q.push_back(vif.wdata);
                    wstrb_q.push_back(vif.wstrb);
                end
            end
        endtask

        // fires once the write response completes; pulls the matching
        // address/data/strb off the queues in FIFO order (AXI guarantees
        // in-order completion on a single-outstanding-ish slave like this one)
        task watch_b();
            axi4lite_seq_item item;
            forever begin
                @(posedge vif.aclk);
                if (vif.bvalid && vif.bready) begin
                    item = axi4lite_seq_item::type_id::create("wr_item");
                    item.do_write   = 1;
                    item.write_done = 1;
                    item.bresp      = vif.bresp;

                    if (awaddr_q.size() > 0) item.awaddr = awaddr_q.pop_front();
                    else `uvm_error("MON", "bvalid seen but awaddr_q is empty")

                    if (wdata_q.size() > 0) begin
                        item.wdata = wdata_q.pop_front();
                        item.wstrb = wstrb_q.pop_front();
                    end
                    else `uvm_error("MON", "bvalid seen but wdata_q is empty")

                    mon_ap.write(item);
                    `uvm_info("MONITOR", $sformatf("write complete addr=0x%0h data=0x%0h strb=%0b bresp=%0b",
                              item.awaddr, item.wdata, item.wstrb, item.bresp), UVM_HIGH)
                end
            end
        endtask

        task watch_ar();
            forever begin
                @(posedge vif.aclk);
                if (vif.arvalid && vif.arready)
                    araddr_q.push_back(vif.araddr);
            end
        endtask

        task watch_r();
            axi4lite_seq_item item;
            forever begin
                @(posedge vif.aclk);
                if (vif.rvalid && vif.rready) begin
                    item = axi4lite_seq_item::type_id::create("rd_item");
                    item.do_read   = 1;
                    item.read_done = 1;
                    item.rdata     = vif.rdata;
                    item.rresp     = vif.rresp;

                    if (araddr_q.size() > 0) item.araddr = araddr_q.pop_front();
                    else `uvm_error("MON", "rvalid seen but araddr_q is empty")

                    mon_ap.write(item);
                    `uvm_info("MONITOR", $sformatf("read complete addr=0x%0h data=0x%0h rresp=%0b",
                              item.araddr, item.rdata, item.rresp), UVM_HIGH)
                end
            end
        endtask

        // lets the scoreboard know when to clear its shadow memory model
        task watch_reset();
            axi4lite_seq_item item;
            bit prev_aresetn = 1'b1;
            forever begin
                @(posedge vif.aclk);
                if (prev_aresetn && !vif.aresetn) begin
                    item = axi4lite_seq_item::type_id::create("rst_item");
                    item.rst = 1;
                    mon_ap.write(item);
                    `uvm_info("MON", "RESET ASSERTED", UVM_NONE)
                end
                prev_aresetn = vif.aresetn;
            end
        endtask

        task run_phase(uvm_phase phase);
            super.run_phase(phase);
            fork
                watch_aw();
                watch_w();
                watch_b();
                watch_ar();
                watch_r();
                watch_reset();
            join_none
        endtask

    endclass
endpackage
