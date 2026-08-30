`timescale 1ns/1ps

module axi4lite_sva (
    input logic        clk,
    input logic        aresetn,
    input logic        awvalid,
    input logic        awready,
    input logic        wvalid,                 // All signals are taken as input because the assertion module only reads (monitors) the DUT signals to check properties.
                                               //it does not drive or modify any signal.
    input logic        wready,
    input logic        bvalid,
    input logic        bready,
    input logic [1:0]  bresp,
    input logic        arvalid,
    input logic        arready,
    input logic        rvalid,
    input logic        rready,
    input logic [1:0]  rresp
);

    ////give names to the assertions such that they can be referenced in the simulation log and reports, and also to make it easier to find them in the code.
    // Disable (ignore) the assertion whenever rst is 0.
    

    //If AWVALID is HIGH and AWREADY is LOW, AWVALID must remain HIGH in the next clock cycle until the address handshake occurs.
    aw_valid_stable: assert property (@(posedge clk) disable iff (!aresetn)  (awvalid && !awready) |=> awvalid)
                     else $error("AWVALID dropped before AWREADY");

    //Once the master asserts WVALID, it must keep it HIGH until the slave accepts the write data by asserting WREADY
    w_valid_stable: assert property (@(posedge clk) disable iff (!aresetn)  (wvalid && !wready) |=> wvalid)
                    else $error("WVALID dropped before WREADY");

    //If ARVALID is HIGH and ARREADY is LOW, ARVALID must remain HIGH in the next clock cycle until the address handshake occurs.
    ar_valid_stable: assert property (@(posedge clk) disable iff (!aresetn)   (arvalid && !arready) |=> arvalid)
                     else $error("ARVALID dropped before ARREADY");

    // BVALID must stay HIGH until BREADY accepts the write response.
    bvalid_stable: assert property (@(posedge clk) disable iff (!aresetn)  (bvalid && !bready) |=> bvalid)
                   else $error("BVALID dropped before BREADY");
    
    // Keep RVALID asserted until the master is ready to receive the read response(rready signal).
    rvalid_stable: assert property (@(posedge clk) disable iff (!aresetn)   (rvalid && !rready) |=> rvalid)
                   else $error("RVALID dropped before RREADY");

    // Check that BRESP gives only the supported response codes: OKAY or SLVERR.RESPONSE Is valid only when the Bvalid is High.
    bresp_legal: assert property (@(posedge clk) disable iff (!aresetn)    bvalid |-> (bresp == 2'b00 || bresp == 2'b10))
                 else $error("BRESP used an unsupported response code");
 
     // Check that RRESP gives only the supported response codes: OKAY or SLVERR.RESPONSE Is valid only when the Rvalid is High.
    rresp_legal: assert property (@(posedge clk) disable iff (!aresetn)    rvalid |-> (rresp == 2'b00 || rresp == 2'b10))
                 else $error("RRESP used an unsupported response code");

    //$isunknown means It checks whether bvalid contains: X → Unknown value Z → High impedance value.
    no_x_bvalid: assert property (@(posedge clk) disable iff (!aresetn)    !$isunknown(bvalid))
                 else $error("BVALID went to X/Z");
    
    no_x_rvalid: assert property (@(posedge clk) disable iff (!aresetn)    !$isunknown(rvalid))
                 else $error("RVALID went to X/Z");

    //These cover properties are used to confirm that important AXI transactions and error cases were actually exercised during simulation.

    cov_write_trasnfer : cover property (@(posedge clk) awvalid && awready);          
    cov_read_transfer  : cover property (@(posedge clk) arvalid && arready);
    cov_write_resp     : cover property (@(posedge clk) bvalid && bready);
    cov_read_resp      : cover property (@(posedge clk) rvalid && rready);
    cov_slverr_w       : cover property (@(posedge clk) bvalid && bready && (bresp == 2'b10));
    cov_slverr_r       : cover property (@(posedge clk) rvalid && rready && (rresp == 2'b10));

endmodule
