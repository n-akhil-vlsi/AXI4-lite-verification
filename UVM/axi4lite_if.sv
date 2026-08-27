`timescale 1ns/1ps
interface axi4lite_if;
    // groups together every DUT pin used to connect the testbench to the axils slave

    logic        aclk;
    logic        aresetn;

    // ---- write address channel ----
    logic        awvalid;
    logic        awready;
    logic [31:0] awaddr;
    logic [2:0]  awprot;

    // ---- write data channel ----
    logic        wvalid;
    logic        wready;
    logic [31:0] wdata;
    logic [3:0]  wstrb;

    // ---- write response channel ----
    logic        bvalid;
    logic        bready;
    logic [1:0]  bresp;

    // ---- read address channel ----
    logic        arvalid;
    logic        arready;
    logic [31:0] araddr;
    logic [2:0]  arprot;

    // ---- read data channel ----
    logic        rvalid;
    logic        rready;
    logic [31:0] rdata;
    logic [1:0]  rresp;
endinterface
