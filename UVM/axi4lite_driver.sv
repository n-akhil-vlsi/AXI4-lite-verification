`timescale 1ns/1ps
package axi4lite_driver_pkg;
    import uvm_pkg::*;
    import axi4lite_seq_item_pkg::*;
    import axi4lite_config_obj_pkg::*;
    `include "uvm_macros.svh"

    class axi4lite_driver extends uvm_driver #(axi4lite_seq_item);
        `uvm_component_utils(axi4lite_driver)

        virtual axi4lite_if     vif;                 // set in the agent (drv.vif = cfg.axi4lite_vif)
        axi4lite_config_obj     cfg;
        axi4lite_seq_item       req_item;

        function new(string name = "axi4lite_driver", uvm_component parent = null);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(axi4lite_config_obj)::get(this, "", "CFG", cfg))
                `uvm_fatal("build_phase", "driver could not get config object")
        endfunction

        // holds reset for a few clocks and puts every channel back to idle
        task do_reset();
            vif.aresetn <= 1'b0;
            vif.awvalid <= 1'b0;
            vif.awaddr  <= '0;
            vif.awprot  <= '0;
            vif.wvalid  <= 1'b0;
            vif.wdata   <= '0;
            vif.wstrb   <= '0;
            vif.bready  <= 1'b0;
            vif.arvalid <= 1'b0;
            vif.araddr  <= '0;
            vif.arprot  <= '0;
            vif.rready  <= 1'b0;
            repeat (5) @(posedge vif.aclk);
            vif.aresetn <= 1'b1;
            @(posedge vif.aclk);
        endtask

        // drives AW and W independently (with optional relative skew) 
        //so both channel orderings, and simultaneous arrival, get exercised.

        task do_write(axi4lite_seq_item item);
            fork
                begin
                    repeat (item.aw_delay_cycles) @(posedge vif.aclk);
                    vif.awvalid <= 1'b1;
                    vif.awaddr  <= item.awaddr;
                    vif.awprot  <= 3'b000;
                    @(posedge vif.aclk);
                    while (!vif.awready) @(posedge vif.aclk);                         //"Keep AWVALID asserted and wait until the slave says it is ready by asserting AWREADY."
                    vif.awvalid <= 1'b0;
                end
                begin
                    repeat (item.w_delay_cycles) @(posedge vif.aclk);
                    vif.wvalid <= 1'b1;
                    vif.wdata  <= item.wdata;
                    vif.wstrb  <= item.wstrb;
                    @(posedge vif.aclk);
                    while (!vif.wready) @(posedge vif.aclk);                         //when the wready is high then it moves to the next step.
                    vif.wvalid <= 1'b0;
                end
            join

            repeat (item.bready_delay_cycles + item.resp_hold_cycles) @(posedge vif.aclk);            //how long the master waits before accepting the slave's write response.
            vif.bready <= 1'b1;
            @(posedge vif.aclk);
            while (!vif.bvalid) @(posedge vif.aclk);
            vif.bready <= 1'b0;

            `uvm_info("DRIVER", $sformatf("Driving WRITE addr=0x%0h data=0x%0h strb=%0b", item.awaddr, item.wdata, item.wstrb), UVM_HIGH)
        endtask

        // drives AR, then holds rready until rvalid completes the read
        task do_read(axi4lite_seq_item item);
            vif.arvalid <= 1'b1;
            vif.araddr  <= item.araddr;
            vif.arprot  <= 3'b000;
            @(posedge vif.aclk);
            while (!vif.arready) @(posedge vif.aclk);
            vif.arvalid <= 1'b0;

            repeat (item.rready_delay_cycles + item.resp_hold_cycles) @(posedge vif.aclk);
            vif.rready <= 1'b1;
            @(posedge vif.aclk);
            while (!vif.rvalid) @(posedge vif.aclk);
            vif.rready <= 1'b0;

            `uvm_info("DRIVER", $sformatf("Driving READ addr=0x%0h", item.araddr), UVM_HIGH)
        endtask

        task run_phase(uvm_phase phase);
            super.run_phase(phase);
            vif.awvalid <= 1'b0;
            vif.wvalid  <= 1'b0;
            vif.bready  <= 1'b0;
            vif.arvalid <= 1'b0;
            vif.rready  <= 1'b0;

            forever 
            begin                                           // continuously services the sequencer for the whole run
                seq_item_port.get_next_item(req_item);
                if (req_item.rst) 
                begin
                    do_reset();
                end
                
                else 
                begin
                    fork                                                 // write and read run in parallel -> tests the two
                        begin                                            // independent FSMs concurrently, like the DUT intends
                            if (req_item.do_write) 
                            do_write(req_item);
                        end
                        begin
                            if (req_item.do_read) 
                            do_read(req_item);
                        end
                    join
                end
                seq_item_port.item_done();
                `uvm_info("run_phase", req_item.convert2string(), UVM_HIGH)
            end
        endtask

    endclass
endpackage
