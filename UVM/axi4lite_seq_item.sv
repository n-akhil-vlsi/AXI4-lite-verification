`timescale 1ns/1ps
package axi4lite_seq_item_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    //sequence_items is like the Transaction class in the system verilog.Used to store all the input and the ouput signals except the global signals.
    //And these are controlled by the constraints.
    //A transaction contains only the fields required by the driver to apply stimulus and by the monitor to store observed results; it does not contain every physical interface signal.

    typedef enum bit [1:0] {ADDR_OK, ADDR_MISALIGNED, ADDR_OOR} addr_mode_e;

    class axi4lite_seq_item extends uvm_sequence_item;

        `uvm_object_utils(axi4lite_seq_item)


        // ---- inputs driven by the driver ----
        rand bit        rst;
        rand bit        do_write;      // control bit: perform a write this item.
        rand bit [31:0] awaddr;
        rand bit [31:0] wdata;
        rand bit [3:0]  wstrb;
        rand bit        do_read;       // control bit: perform a read this item.
        rand bit [31:0] araddr;

        rand addr_mode_e waddr_mode;            //waddr_mode Controls the write address awaddr.
        rand addr_mode_e raddr_mode;

        rand int unsigned aw_delay_cycles;             //controls how many clock cycles the driver waits before sending the write address.After these many cycles we make AWVALID HIGH.
        rand int unsigned w_delay_cycles;              //how many clock cycles to wait before sending the Write Data (W) transaction.after these many cycles we assert WVALID HIGH.

        rand int unsigned bready_delay_cycles;         //how many cycles the master waits before asserting BREADY.
        rand int unsigned rready_delay_cycles;         //how many cycles the master waits before asserting RREADY.

        int unsigned resp_hold_cycles;                 //record or control how long a response is held.


        // ---- outputs captured by the monitor ----
        bit        write_done;
        bit [1:0]  bresp;
        bit        read_done;
        bit [1:0]  rresp;
        bit [31:0] rdata;

        int WR_ON_DIST = 70;   // % of the time do_write is 1
        int RD_ON_DIST = 70;   // % of the time do_read  is 1

        function new(string name = "axi4lite_seq_item");
            super.new(name);
        endfunction

        constraint rst_c { rst dist {0 :/ 97, 1 :/ 3};}

        constraint wr_c { do_write dist {1 :/ WR_ON_DIST, 0 :/ (100 - WR_ON_DIST)};}

        constraint rd_c { do_read  dist {1 :/ RD_ON_DIST, 0 :/ (100 - RD_ON_DIST)};}

        // 80% legal word-aligned in-range address, 10% misaligned, 10% out-of-range
        constraint waddr_mode_c { waddr_mode dist {ADDR_OK :/ 80, ADDR_MISALIGNED :/ 10, ADDR_OOR :/ 10};}
       
        constraint raddr_mode_c { raddr_mode dist {ADDR_OK :/ 80, ADDR_MISALIGNED :/ 10, ADDR_OOR :/ 10};}

        // NUM_WORDS = 16 in the DUT -> legal byte range is 0..60, word aligned
        constraint awaddr_c {
            (waddr_mode == ADDR_OK)         -> (awaddr inside {[0:60]} && awaddr[1:0] == 2'b00);
            (waddr_mode == ADDR_MISALIGNED) -> (awaddr inside {[0:63]} && awaddr[1:0] != 2'b00);
            (waddr_mode == ADDR_OOR)        -> (awaddr inside {[64:4095]});
        }

        constraint araddr_c {
            (raddr_mode == ADDR_OK)         -> (araddr inside {[0:60]} && araddr[1:0] == 2'b00);
            (raddr_mode == ADDR_MISALIGNED) -> (araddr inside {[0:63]} && araddr[1:0] != 2'b00);
            (raddr_mode == ADDR_OOR)        -> (araddr inside {[64:4095]});
        }

        constraint wstrb_c {wstrb dist {4'b1111 :/ 60, 4'b0011 :/ 10, 4'b1100 :/ 10, 4'b0001 :/ 5,  4'b0010 :/ 5,  4'b0100 :/ 5, 4'b1000 :/ 5};}

        constraint delay_c {
            aw_delay_cycles inside {[0:4]};
            w_delay_cycles  inside {[0:4]};
            !(aw_delay_cycles > 0 && w_delay_cycles > 0);   // Both aw_delay_cycles and w_delay_cycles cannot be greater than 0 at the same time.
            aw_delay_cycles dist {0 :/ 70, [1:4] :/ 30};
            w_delay_cycles  dist {0 :/ 70, [1:4] :/ 30};
        }

        constraint stall_c {
            bready_delay_cycles inside {[0:4]};
            rready_delay_cycles inside {[0:4]};
            bready_delay_cycles dist {0 :/ 60, [1:4] :/ 40};
            rready_delay_cycles dist {0 :/ 60, [1:4] :/ 40};
        }

        function string convert2string();
            return $sformatf("rst=%0b do_write=%0b awaddr=0x%0h wdata=0x%0h wstrb=%0b aw_dly=%0d w_dly=%0d bready_dly=%0d resp_hold=%0d do_read=%0b araddr=0x%0h rready_dly=%0d | write_done=%0b bresp=%0b read_done=%0b rdata=0x%0h rresp=%0b",
                              rst, do_write, awaddr, wdata, wstrb, aw_delay_cycles, w_delay_cycles,
                              bready_delay_cycles, resp_hold_cycles, do_read, araddr, rready_delay_cycles,
                              write_done, bresp, read_done, rdata, rresp);
        endfunction

    endclass

endpackage
