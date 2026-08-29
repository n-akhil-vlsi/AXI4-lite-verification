`timescale 1ns/1ps
interface axi4lite_if;

    // all the input and the output signals.
    logic        aclk;
    logic        aresetn;

    logic        awvalid;
    logic        awready;
    logic [31:0] awaddr;
    logic [2:0]  awprot;

    logic        wvalid;
    logic        wready;
    logic [31:0] wdata;
    logic [3:0]  wstrb;

    logic        bvalid;
    logic        bready;
    logic [1:0]  bresp;

    logic        arvalid;
    logic        arready;
    logic [31:0] araddr;
    logic [2:0]  arprot;

    logic        rvalid;
    logic        rready;
    logic [31:0] rdata;
    logic [1:0]  rresp;

endinterface
