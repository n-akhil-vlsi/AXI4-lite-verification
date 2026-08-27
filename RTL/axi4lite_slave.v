`timescale 1ns / 1ps
 
module axils
(
 input  wire        s_axi_aclk,
 input  wire        s_axi_aresetn,
 
 // Write address channel
 input  wire        s_axi_awvalid,
 output reg         s_axi_awready,
 input  wire [31:0] s_axi_awaddr,
 input  wire [2:0]  s_axi_awprot,
 
 // Write data channel
 input  wire        s_axi_wvalid,
 output reg         s_axi_wready,
 input  wire [31:0] s_axi_wdata,
 input  wire [3:0]  s_axi_wstrb,
 
 // Write response channel
 output reg         s_axi_bvalid,
 input  wire        s_axi_bready,
 output reg  [1:0]  s_axi_bresp,
 
 // Read address channel
 input  wire        s_axi_arvalid,
 output reg         s_axi_arready,
 input  wire [31:0] s_axi_araddr,
 input  wire [2:0]  s_axi_arprot,
 
 // Read data channel
 output reg         s_axi_rvalid,
 input  wire        s_axi_rready,
 output reg  [31:0] s_axi_rdata,
 output reg  [1:0]  s_axi_rresp
);
 
// ---- Memory / address decode ----
localparam NUM_WORDS   = 16;
localparam ADDR_HI_BIT = 5;   // 16 words * 4 bytes = 64B -> addr[5:2] = word index
localparam ADDR_LO_BIT = 2;
 
localparam RESP_OKAY   = 2'b00;
localparam RESP_SLVERR = 2'b10;
 
reg [31:0] mem [15:0];
integer i;
 
function automatic addr_ok(input [31:0] byte_addr);
   begin
      addr_ok = (byte_addr[1:0] == 2'b00) &&      // word-aligned
                (byte_addr < (NUM_WORDS * 4));     // in range
   end
endfunction
 
// =====================================================================
// WRITE CHANNEL  -- AW and W are captured independently, in any order,
// and only proceed to the memory update once BOTH have arrived.
// =====================================================================
localparam WIDLE    = 0,
           WCOMPUTE = 1,
           WRESP    = 2;
 
reg [1:0]  wstate;
reg        aw_hs_done, w_hs_done;
reg [31:0] waddr_r, wdata_r;
reg [3:0]  wstrb_r;
reg        waddr_valid_r;
 
always @(posedge s_axi_aclk) begin
  if (!s_axi_aresetn) begin
    for (i = 0; i < 16; i = i + 1) mem[i] <= 32'h0;
    wstate        <= WIDLE;
    aw_hs_done    <= 1'b0;
    w_hs_done     <= 1'b0;
    s_axi_awready <= 1'b0;
    s_axi_wready  <= 1'b0;
    s_axi_bvalid  <= 1'b0;
    s_axi_bresp   <= RESP_OKAY;
    waddr_r       <= 32'h0;
    wdata_r       <= 32'h0;
    wstrb_r       <= 4'h0;
    waddr_valid_r <= 1'b0;
  end else begin
    case (wstate)
 
      WIDLE: begin
        // Accept AW independently of W
        if (s_axi_awvalid && !aw_hs_done) begin
          s_axi_awready <= 1'b1;
          waddr_r       <= s_axi_awaddr;
          aw_hs_done    <= 1'b1;
        end else begin
          s_axi_awready <= 1'b0;
        end
 
        // Accept W independently of AW
        if (s_axi_wvalid && !w_hs_done) begin
          s_axi_wready <= 1'b1;
          wdata_r      <= s_axi_wdata;
          wstrb_r      <= s_axi_wstrb;
          w_hs_done    <= 1'b1;
        end else begin
          s_axi_wready <= 1'b0;
        end
 
        // Move on once both sides have completed their handshake
        // (covers AW-first, W-first, and simultaneous arrival)
        if ((aw_hs_done || (s_axi_awvalid && !aw_hs_done)) &&
            (w_hs_done  || (s_axi_wvalid  && !w_hs_done)))
          wstate <= WCOMPUTE;
      end
 
      WCOMPUTE: begin
        s_axi_awready <= 1'b0;
        s_axi_wready  <= 1'b0;
        waddr_valid_r <= addr_ok(waddr_r);
 
        if (addr_ok(waddr_r)) begin
          // Byte-strobe write: preserve bytes not selected by wstrb
          mem[waddr_r[ADDR_HI_BIT:ADDR_LO_BIT]][7:0]   <=
            wstrb_r[0] ? wdata_r[7:0]   : mem[waddr_r[ADDR_HI_BIT:ADDR_LO_BIT]][7:0];
          mem[waddr_r[ADDR_HI_BIT:ADDR_LO_BIT]][15:8]  <=
            wstrb_r[1] ? wdata_r[15:8]  : mem[waddr_r[ADDR_HI_BIT:ADDR_LO_BIT]][15:8];
          mem[waddr_r[ADDR_HI_BIT:ADDR_LO_BIT]][23:16] <=
            wstrb_r[2] ? wdata_r[23:16] : mem[waddr_r[ADDR_HI_BIT:ADDR_LO_BIT]][23:16];
          mem[waddr_r[ADDR_HI_BIT:ADDR_LO_BIT]][31:24] <=
            wstrb_r[3] ? wdata_r[31:24] : mem[waddr_r[ADDR_HI_BIT:ADDR_LO_BIT]][31:24];
        end
        // else: invalid address -> no memory write, SLVERR reported in WRESP
 
        wstate <= WRESP;
      end
 
      WRESP: begin
        s_axi_bvalid <= 1'b1;
        s_axi_bresp  <= waddr_valid_r ? RESP_OKAY : RESP_SLVERR;
        // Per AXI spec: VALID must stay high until READY is seen.
        // No internal timeout here -- we hold indefinitely, as required.
        // Gate on the REGISTERED bvalid (not just bready) so the
        // handshake can't complete in the same cycle bvalid is first
        // raised -- BVALID must be visible on the bus for >=1 full
        // cycle even if BREADY was already asserted early.
        if (s_axi_bvalid && s_axi_bready) begin
          s_axi_bvalid <= 1'b0;
          aw_hs_done   <= 1'b0;
          w_hs_done    <= 1'b0;
          wstate       <= WIDLE;
        end
      end
 
      default: wstate <= WIDLE;
    endcase
  end
end
 
// =====================================================================
// READ CHANNEL  -- fully independent of the write channel/state.
// =====================================================================
localparam RIDLE  = 0,
           RFETCH = 1,
           RRESP  = 2;
 
reg [1:0]  rstate;
reg [31:0] raddr_r, rdata_r;
reg        raddr_valid_r;
 
always @(posedge s_axi_aclk) begin
  if (!s_axi_aresetn) begin
    rstate        <= RIDLE;
    s_axi_arready <= 1'b0;
    s_axi_rvalid  <= 1'b0;
    s_axi_rdata   <= 32'h0;
    s_axi_rresp   <= RESP_OKAY;
    raddr_r       <= 32'h0;
    rdata_r       <= 32'h0;
    raddr_valid_r <= 1'b0;
  end else begin
    case (rstate)
 
      RIDLE: begin
        if (s_axi_arvalid) begin
          s_axi_arready <= 1'b1;
          raddr_r       <= s_axi_araddr;
          rstate        <= RFETCH;
        end else begin
          s_axi_arready <= 1'b0;
        end
      end
 
      RFETCH: begin
        s_axi_arready <= 1'b0;
        raddr_valid_r <= addr_ok(raddr_r);
        // Defensive guard (index is already always in-range since it's a
        // 4-bit slice of the address, but kept explicit/consistent with
        // the write-path style).
        rdata_r       <= addr_ok(raddr_r) ? mem[raddr_r[ADDR_HI_BIT:ADDR_LO_BIT]] : 32'h0;
        rstate        <= RRESP;
      end
 
      RRESP: begin
        s_axi_rvalid <= 1'b1;
        s_axi_rdata  <= raddr_valid_r ? rdata_r : 32'h0;
        s_axi_rresp  <= raddr_valid_r ? RESP_OKAY : RESP_SLVERR;
        // No internal timeout -- RVALID held until RREADY, per spec.
        // Gate on the REGISTERED rvalid (not just rready) so the
        // handshake can't complete in the same cycle rvalid is first
        // raised -- RVALID must be visible on the bus for >=1 full
        // cycle even if RREADY was already asserted early.
        if (s_axi_rvalid && s_axi_rready) begin
          s_axi_rvalid <= 1'b0;
          rstate       <= RIDLE;
        end
      end
 
      default: rstate <= RIDLE;
    endcase
  end
end
 
endmodule
