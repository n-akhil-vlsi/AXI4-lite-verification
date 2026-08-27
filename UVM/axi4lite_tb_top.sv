`timescale 1ns / 1ps

import uvm_pkg::*;
import axi4lite_test_pkg::*;
`include "uvm_macros.svh"

module axi4lite_tb_top;

    // 100 MHz clock
    bit clk;
    always #5 clk = ~clk;   // 10ns period = 100MHz

    axi4lite_if aif ();
    assign aif.aclk = clk;

    axils dut (
        .s_axi_aclk    (aif.aclk),
        .s_axi_aresetn (aif.aresetn),

        .s_axi_awvalid (aif.awvalid),
        .s_axi_awready (aif.awready),
        .s_axi_awaddr  (aif.awaddr),
        .s_axi_awprot  (aif.awprot),

        .s_axi_wvalid  (aif.wvalid),
        .s_axi_wready  (aif.wready),
        .s_axi_wdata   (aif.wdata),
        .s_axi_wstrb   (aif.wstrb),

        .s_axi_bvalid  (aif.bvalid),
        .s_axi_bready  (aif.bready),
        .s_axi_bresp   (aif.bresp),

        .s_axi_arvalid (aif.arvalid),
        .s_axi_arready (aif.arready),
        .s_axi_araddr  (aif.araddr),
        .s_axi_arprot  (aif.arprot),

        .s_axi_rvalid  (aif.rvalid),
        .s_axi_rready  (aif.rready),
        .s_axi_rdata   (aif.rdata),
        .s_axi_rresp   (aif.rresp)
    );

    // bind the protocol-assertion checker straight into the DUT so it can
    // see the AXI signals without any extra wiring in this top module
    bind axils axi4lite_sva u_axi4lite_sva (
        .clk      (s_axi_aclk),
        .aresetn  (s_axi_aresetn),
        .awvalid  (s_axi_awvalid),
        .awready  (s_axi_awready),
        .wvalid   (s_axi_wvalid),
        .wready   (s_axi_wready),
        .bvalid   (s_axi_bvalid),
        .bready   (s_axi_bready),
        .bresp    (s_axi_bresp),
        .arvalid  (s_axi_arvalid),
        .arready  (s_axi_arready),
        .rvalid   (s_axi_rvalid),
        .rready   (s_axi_rready),
        .rresp    (s_axi_rresp)
    );

    initial begin
        uvm_config_db#(virtual axi4lite_if)::set(null, "uvm_test_top", "AXIL_IF", aif);
        // driver and monitor don't need their own get() for the interface -
        // they receive it through axi4lite_config_obj instead
        run_test();
    end

endmodule
