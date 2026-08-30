`timescale 1ns / 1ps

import uvm_pkg::*;
import axi4lite_test_pkg::*;
`include "uvm_macros.svh"

module axi4lite_tb_top;

    // 100 MHz clock
    bit clk;
    always #5 clk = ~clk;  

    axi4lite_if aif ();                                  //axi4lite_if → interface type,   aif → actual interface instance
    assign aif.aclk = clk;                               //virtual axi4lite_if vif;------------in the monitor,scoreboard.
                                                         //virtual axi4lite_if axi4lite_vif;-------in the config_obj
    axils dut (                                          //all has the same interface type(axi4lite_if).
        .s_axi_aclk    (aif.aclk),                       //vif,axi4lite_vif ---They are virtual interface handles that point to the same actual instance aif.
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

    // bind the protocol-assertion checker straight into the DUT.
    //bind <target_module> <assertion_module> <instance_name> ().

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


    //Test file (axi4lite_test) → Gets "AXIL_IF" from uvm_config_db and stores it in cfg.axi4lite_vif.
    //The test receives aif first through uvm_config_db, stores it in the config object, and then the agent passes it to the driver and monitor.
    //TB_TOP → Config DB → Test → Config Object → Agent → Driver.
    
    initial 
    begin
        uvm_config_db#(virtual axi4lite_if)::set(null, "uvm_test_top", "AXIL_IF", aif);                    
        run_test();
    end

endmodule
