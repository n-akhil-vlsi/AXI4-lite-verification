`timescale 1ns/1ps
package axi4lite_sequence_pkg;
    import uvm_pkg::*;
    import axi4lite_seq_item_pkg::*;
    `include "uvm_macros.svh"          // a sequence creates+fills seq_items and sends them to the driver through the sequencer.


    // 1) checks the DUT recovers cleanly after reset - one write and one read are issued right after release to confirm it comes back alive
    class axi4lite_reset_sequence extends uvm_sequence #(axi4lite_seq_item);
        `uvm_object_utils(axi4lite_reset_sequence)
       
        function new(string name = "axi4lite_reset_sequence");
            super.new(name);
        endfunction
        
        task body();
            axi4lite_seq_item item;

            // assert reset
            item = axi4lite_seq_item::type_id::create("item");
            start_item(item);                                  // asks the sequencer if the driver is free
            item.rst      = 1;
            item.do_write = 0;
            item.do_read  = 0;
            finish_item(item);                                 // sends the transaction to the driver

            // release reset, idle one cycle
            item = axi4lite_seq_item::type_id::create("item");
            start_item(item);
            item.rst      = 0;
            item.do_write = 0;
            item.do_read  = 0;
            finish_item(item);

            // one write post-reset, to confirm the DUT recovered
            item = axi4lite_seq_item::type_id::create("item");
            start_item(item);
            item.rst        = 0;
            item.do_write   = 1;
            item.waddr_mode = ADDR_OK;
            item.awaddr     = 32'h0;
            item.wdata      = $urandom;
            item.wstrb      = 4'b1111;
            item.do_read    = 0;
            finish_item(item);

            // one read post-reset, to confirm the DUT recovered
            item = axi4lite_seq_item::type_id::create("item");
            start_item(item);
            item.rst        = 0;
            item.do_read    = 1;
            item.raddr_mode = ADDR_OK;
            item.araddr     = 32'h0;
            item.do_write   = 0;
            finish_item(item);
        endtask
    endclass

    // 2) writes every legal word address once, so every memory location gets touched at least once by this sequence alone
    class axi4lite_write_only_sequence extends uvm_sequence #(axi4lite_seq_item);
        `uvm_object_utils(axi4lite_write_only_sequence)
        int num_words = 16;

        function new(string name = "axi4lite_write_only_sequence");
            super.new(name);
        endfunction

        task body();
            axi4lite_seq_item item;
            for (int i = 0; i < num_words; i++) 
            begin
                item = axi4lite_seq_item::type_id::create("item");
                start_item(item);
                item.rst        = 0;
                item.do_write   = 1;
                item.waddr_mode = ADDR_OK;
                item.awaddr     = i * 4;
                item.wdata      = $urandom;
                item.wstrb      = 4'b1111;
                item.do_read    = 0;
                finish_item(item);
            end
        endtask
    endclass

    // 3) reads every legal word address once
    class axi4lite_read_only_sequence extends uvm_sequence #(axi4lite_seq_item);
        `uvm_object_utils(axi4lite_read_only_sequence)
        int num_words = 16;

        function new(string name = "axi4lite_read_only_sequence");
            super.new(name);
        endfunction

        task body();
            axi4lite_seq_item item;
            for (int i = 0; i < num_words; i++) 
            begin
                item = axi4lite_seq_item::type_id::create("item");
                start_item(item);
                item.rst        = 0;
                item.do_read    = 1;
                item.raddr_mode = ADDR_OK;
                item.araddr     = i * 4;
                item.do_write   = 0;
                finish_item(item);
            end
        endtask
    endclass

    // 4) drives a write and a read at the same time, checking the two
    //    independent FSMs run concurrently without interfering
    class axi4lite_write_read_together_sequence extends uvm_sequence #(axi4lite_seq_item);
        `uvm_object_utils(axi4lite_write_read_together_sequence)
        int num_items = 8;

        function new(string name = "axi4lite_write_read_together_sequence");
            super.new(name);
        endfunction

        task body();
            axi4lite_seq_item item;
            for (int i = 0; i < num_items; i++) 
            begin
                item = axi4lite_seq_item::type_id::create("item");
                start_item(item);
                item.rst        = 0;
                item.do_write   = 1;
                item.waddr_mode = ADDR_OK;
                item.awaddr     = (i % 16) * 4;
                item.wdata      = $urandom;
                item.wstrb      = 4'b1111;
                item.do_read    = 1;
                item.raddr_mode = ADDR_OK;
                item.araddr     = ((i + 1) % 16) * 4;
                finish_item(item);
            end
        endtask
    endclass

    // 5) skews AWVALID against WVALID (and vice versa) across consecutive writes with no idle gap between them - exercises the DUT's
    class axi4lite_back_to_back_sequence extends uvm_sequence #(axi4lite_seq_item);
        `uvm_object_utils(axi4lite_back_to_back_sequence)
        int num_items = 6;

        function new(string name = "axi4lite_back_to_back_sequence");
            super.new(name);
        endfunction
                                                                         //back-to-back sequence specifically tests repeated writes + different AW/W arrival order.
        task body();
            axi4lite_seq_item item;
            for (int i = 0; i < num_items; i++) 
            begin
                item = axi4lite_seq_item::type_id::create("item");
                start_item(item);
                item.rst        = 0;
                item.do_write   = 1;
                item.waddr_mode = ADDR_OK;
                item.awaddr     = (i % 16) * 4;
                item.wdata      = $urandom;
                item.wstrb      = 4'b1111;
                item.do_read    = 0;
                                                                       //AW and W intentionally arrive at different times.
                if (i % 2 == 0) 
                begin
                    item.aw_delay_cycles = 0;
                    item.w_delay_cycles  = 2;   // W arrives late
                end 
                else 
                begin
                    item.aw_delay_cycles = 2;   // AW arrives late
                    item.w_delay_cycles  = 0;
                end
                finish_item(item);
                // deliberately no idle item here - back to back on purpose
            end
        endtask
    endclass

    // 6) forces misaligned addresses on both channels, checks SLVERR
    class axi4lite_misaligned_addr_sequence extends uvm_sequence #(axi4lite_seq_item);
        `uvm_object_utils(axi4lite_misaligned_addr_sequence)
        int num_items = 6;

        function new(string name = "axi4lite_misaligned_addr_sequence");
            super.new(name);
        endfunction

        task body();
            axi4lite_seq_item item;
            for (int i = 0; i < num_items; i++) 
            begin
                item = axi4lite_seq_item::type_id::create("item");
                start_item(item);
                item.rst        = 0;
                item.do_write   = 1;
                item.waddr_mode = ADDR_MISALIGNED;
                item.awaddr     = (i * 4) + 1;      // deliberately unaligned
                item.wdata      = $urandom;
                item.wstrb      = 4'b1111;
                item.do_read    = 1;
                item.raddr_mode = ADDR_MISALIGNED;
                item.araddr     = (i * 4) + 2;      // deliberately unaligned
                finish_item(item);
            end
        endtask
    endclass

   // 7) Tests out-of-range write and read addresses.Checks that the DUT returns SLVERR and does not access invalid memory.
    class axi4lite_out_of_range_sequence extends uvm_sequence #(axi4lite_seq_item);
        `uvm_object_utils(axi4lite_out_of_range_sequence)
        int num_items = 6;

        function new(string name = "axi4lite_out_of_range_sequence");
            super.new(name);
        endfunction

        task body();
            axi4lite_seq_item item;
            for (int i = 0; i < num_items; i++) 
            begin
                item = axi4lite_seq_item::type_id::create("item");
                start_item(item);
                item.rst        = 0;
                item.do_write   = 1;
                item.waddr_mode = ADDR_OOR;
                item.awaddr     = 64 + (i * 4);
                item.wdata      = $urandom;
                item.wstrb      = 4'b1111;
                item.do_read    = 1;
                item.raddr_mode = ADDR_OOR;
                item.araddr     = 64 + (i * 4);
                finish_item(item);
            end
        endtask
    endclass

  // 8) Writes to the same address using different WSTRB patterns and reads it back to check that only the selected bytes are updated.
    class axi4lite_wstrb_sequence extends uvm_sequence #(axi4lite_seq_item);
        `uvm_object_utils(axi4lite_wstrb_sequence)
        
        bit [3:0] patterns[8] = '{4'b1111, 4'b0011, 4'b1100, 4'b0001, 4'b0010, 4'b0100, 4'b1000, 4'b1111};

        function new(string name = "axi4lite_wstrb_sequence");
            super.new(name);
        endfunction

        task body();
            axi4lite_seq_item item;
            foreach (patterns[i]) 
            begin
                item = axi4lite_seq_item::type_id::create("item");
                start_item(item);
                item.rst        = 0;
                item.do_write   = 1;
                item.waddr_mode = ADDR_OK;
                item.awaddr     = 32'h4;          // same word every time
                item.wdata      = $urandom;
                item.wstrb      = patterns[i];
                item.do_read    = 0;
                finish_item(item);

                item = axi4lite_seq_item::type_id::create("item");
                start_item(item);
                item.rst        = 0;
                item.do_read    = 1;
                item.raddr_mode = ADDR_OK;
                item.araddr     = 32'h4;
                item.do_write   = 0;
                finish_item(item);
            end
        endtask
    endclass

    // 9) exercises random small stalls before BREADY/RREADY are asserted instead of always being instantly ready to accept the response,
    //    the master occasionally waits a few cycles first. checks the DUT doesn't assume an always-ready master on the response channels.
    
    class axi4lite_stall_sequence extends uvm_sequence #(axi4lite_seq_item);
        `uvm_object_utils(axi4lite_stall_sequence)
        int num_items = 10;

        function new(string name = "axi4lite_stall_sequence");
            super.new(name);
        endfunction

        task body();
            axi4lite_seq_item item;
            for (int i = 0; i < num_items; i++) 
            begin
                item = axi4lite_seq_item::type_id::create("item");
                start_item(item);
                item.rst                 = 0;
                item.do_write            = (i % 2 == 0);
                item.waddr_mode          = ADDR_OK;
                item.awaddr              = (i % 16) * 4;
                item.wdata               = $urandom;
                item.wstrb               = 4'b1111;
                item.do_read             = (i % 2 == 1);
                item.raddr_mode          = ADDR_OK;
                item.araddr              = (i % 16) * 4;
                item.aw_delay_cycles     = 0;
                item.w_delay_cycles      = 0;
                item.resp_hold_cycles    = 0;
                item.bready_delay_cycles = $urandom_range(0, 4);
                item.rready_delay_cycles = $urandom_range(0, 4);
                finish_item(item);
            end
        endtask
    endclass

    // 10) Waits 50 cycles before accepting the write and read responses(this is done by the Master).
    //     Checks that the DUT keeps the response valid during this wait.
    //     Ensures the DUT does not timeout or remove the response early.

    class axi4lite_response_backpressure_sequence extends uvm_sequence #(axi4lite_seq_item);
        `uvm_object_utils(axi4lite_response_backpressure_sequence)
        int          num_items       = 4;
        int unsigned hold_cycles     = 50;  

        function new(string name = "axi4lite_response_backpressure_sequence");
            super.new(name);
        endfunction

        task body();
            axi4lite_seq_item item;
            for (int i = 0; i < num_items; i++) 
            begin
                // one long-held write
                item = axi4lite_seq_item::type_id::create("item");
                start_item(item);
                item.rst              = 0;
                item.do_write         = 1;                                       //The master waits 50 cycles then accept the write and read responses. 
                item.waddr_mode       = ADDR_OK;
                item.awaddr           = (i % 16) * 4;
                item.wdata            = $urandom;
                item.wstrb            = 4'b1111;
                item.do_read          = 0;
                item.aw_delay_cycles  = 0;
                item.w_delay_cycles   = 0;
                item.bready_delay_cycles = 0;
                item.resp_hold_cycles = hold_cycles;                                //Set the number of cycles for which the response should be held before the master accepts it.
                finish_item(item);

                // one long-held read
                item = axi4lite_seq_item::type_id::create("item");
                start_item(item);
                item.rst              = 0;
                item.do_read          = 1;
                item.raddr_mode       = ADDR_OK;
                item.araddr           = (i % 16) * 4;
                item.do_write         = 0;
                item.rready_delay_cycles = 0;
                item.resp_hold_cycles = hold_cycles;
                finish_item(item);
            end
        endtask
    endclass


   // 11) Generates 150 completely random transactions with different resets,writes, reads, valid/invalid addresses, delays, and response stalls.
    class axi4lite_random_sequence extends uvm_sequence #(axi4lite_seq_item);
        `uvm_object_utils(axi4lite_random_sequence)
        int num_items = 150;

        function new(string name = "axi4lite_random_sequence");
            super.new(name);
        endfunction

        task body();
            axi4lite_seq_item item;
            for (int i = 0; i < num_items; i++) 
            begin
                item = axi4lite_seq_item::type_id::create("item");
                start_item(item);
                assert (item.randomize());
                finish_item(item);
            end
        endtask
    endclass

    // 12) master sequence - runs every scenario above back to back on the
    //     same sequencer
    class axi4lite_all_scenarios_sequence extends uvm_sequence #(axi4lite_seq_item);
        `uvm_object_utils(axi4lite_all_scenarios_sequence)

        axi4lite_reset_sequence               reset_seq;
        axi4lite_write_only_sequence          wr_only_seq;
        axi4lite_read_only_sequence           rd_only_seq;
        axi4lite_write_read_together_sequence wr_rd_seq;
        axi4lite_back_to_back_sequence        b2b_seq;
        axi4lite_misaligned_addr_sequence     misaligned_seq;
        axi4lite_out_of_range_sequence        oor_seq;
        axi4lite_wstrb_sequence               wstrb_seq;
        axi4lite_stall_sequence               stall_seq;
        axi4lite_response_backpressure_sequence backpressure_seq;
        axi4lite_random_sequence              rand_seq;

        function new(string name = "axi4lite_all_scenarios_sequence");
            super.new(name);
        endfunction

         //m_sequencer is simply the handle (pointer) to the sequencer on which the current sequence is running. UVM automatically provides it.
        //the sequencer is in the agent and the sequence is not in the agent,so if we write axi4lite_sequencer the sequence does not identify it.
        //so UVM automatically stores that sequencer's handle in m_sequencer, so the sequence can use m_sequencer without knowing the actual sequencer variable or its location.
        
        task body();
            `uvm_info("body", "running reset scenario", UVM_NONE)
            reset_seq = axi4lite_reset_sequence::type_id::create("reset_seq");
            reset_seq.start(m_sequencer, this);

            `uvm_info("body", "running write only scenario", UVM_NONE)
            wr_only_seq = axi4lite_write_only_sequence::type_id::create("wr_only_seq");
            wr_only_seq.start(m_sequencer, this);

            `uvm_info("body", "running read only scenario", UVM_NONE)
            rd_only_seq = axi4lite_read_only_sequence::type_id::create("rd_only_seq");
            rd_only_seq.start(m_sequencer, this);

            `uvm_info("body", "running write+read together scenario", UVM_NONE)
            wr_rd_seq = axi4lite_write_read_together_sequence::type_id::create("wr_rd_seq");
            wr_rd_seq.start(m_sequencer, this);

            `uvm_info("body", "running back to back skewed scenario", UVM_NONE)
            b2b_seq = axi4lite_back_to_back_sequence::type_id::create("b2b_seq");
            b2b_seq.start(m_sequencer, this);

            `uvm_info("body", "running misaligned address scenario", UVM_NONE)
            misaligned_seq = axi4lite_misaligned_addr_sequence::type_id::create("misaligned_seq");
            misaligned_seq.start(m_sequencer, this);

            `uvm_info("body", "running out of range address scenario", UVM_NONE)
            oor_seq = axi4lite_out_of_range_sequence::type_id::create("oor_seq");
            oor_seq.start(m_sequencer, this);

            `uvm_info("body", "running wstrb sweep scenario", UVM_NONE)
            wstrb_seq = axi4lite_wstrb_sequence::type_id::create("wstrb_seq");
            wstrb_seq.start(m_sequencer, this);

            `uvm_info("body", "running valid/ready stall scenario", UVM_NONE)
            stall_seq = axi4lite_stall_sequence::type_id::create("stall_seq");
            stall_seq.start(m_sequencer, this);

            `uvm_info("body", "running response backpressure scenario", UVM_NONE)
            backpressure_seq = axi4lite_response_backpressure_sequence::type_id::create("backpressure_seq");
            backpressure_seq.start(m_sequencer, this);

            `uvm_info("body", "running random stress scenario", UVM_NONE)
            rand_seq = axi4lite_random_sequence::type_id::create("rand_seq");
            rand_seq.start(m_sequencer, this);

            `uvm_info("body", "all scenarios done", UVM_NONE)
        endtask
    endclass

endpackage
