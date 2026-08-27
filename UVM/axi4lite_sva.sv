`timescale 1ns/1ps

// checks basic AXI4-Lite handshake rules on the DUT's own ports. bound
// straight into axils so it can see the interface signals without any
// extra wiring in the testbench.
module axi4lite_sva (
    input logic        clk,
    input logic        aresetn,
    input logic        awvalid,
    input logic        awready,
    input logic        wvalid,
    input logic        wready,
    input logic        bvalid,
    input logic        bready,
    input logic [1:0]  bresp,
    input logic        arvalid,
    input logic        arready,
    input logic         rvalid,
    input logic        rready,
    input logic [1:0]  rresp
);

    // VALID must never be dropped before its READY is seen - the master
    // must hold the transfer until the slave accepts it (AXI4 rule).
    aw_valid_stable: assert property (@(posedge clk) disable iff (!aresetn)
        (awvalid && !awready) |=> awvalid)
        else $error("AWVALID dropped before AWREADY");

    w_valid_stable: assert property (@(posedge clk) disable iff (!aresetn)
        (wvalid && !wready) |=> wvalid)
        else $error("WVALID dropped before WREADY");

    ar_valid_stable: assert property (@(posedge clk) disable iff (!aresetn)
        (arvalid && !arready) |=> arvalid)
        else $error("ARVALID dropped before ARREADY");

    // once BVALID/RVALID is asserted it must stay high until the
    // corresponding READY is seen (checked on the slave's own outputs)
    bvalid_stable: assert property (@(posedge clk) disable iff (!aresetn)
        (bvalid && !bready) |=> bvalid)
        else $error("BVALID dropped before BREADY");

    rvalid_stable: assert property (@(posedge clk) disable iff (!aresetn)
        (rvalid && !rready) |=> rvalid)
        else $error("RVALID dropped before RREADY");

    // BRESP/RRESP must be a legal AXI4-Lite response code (this slave only
    // ever returns OKAY or SLVERR, never EXOKAY/DECERR)
    bresp_legal: assert property (@(posedge clk) disable iff (!aresetn)
        bvalid |-> (bresp == 2'b00 || bresp == 2'b10))
        else $error("BRESP used an unsupported response code");

    rresp_legal: assert property (@(posedge clk) disable iff (!aresetn)
        rvalid |-> (rresp == 2'b00 || rresp == 2'b10))
        else $error("RRESP used an unsupported response code");

    // no X on any output-facing valid/resp signal once out of reset
    no_x_bvalid: assert property (@(posedge clk) disable iff (!aresetn) !$isunknown(bvalid))
        else $error("BVALID went to X/Z");
    no_x_rvalid: assert property (@(posedge clk) disable iff (!aresetn) !$isunknown(rvalid))
        else $error("RVALID went to X/Z");

    cov_write_xfer : cover property (@(posedge clk) awvalid && awready);
    cov_read_xfer  : cover property (@(posedge clk) arvalid && arready);
    cov_write_resp : cover property (@(posedge clk) bvalid && bready);
    cov_read_resp  : cover property (@(posedge clk) rvalid && rready);
    cov_slverr_w   : cover property (@(posedge clk) bvalid && bready && (bresp == 2'b10));
    cov_slverr_r   : cover property (@(posedge clk) rvalid && rready && (rresp == 2'b10));

endmodule
