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
 

//Each memory location contains 4 bytes (32 bits). There are 16 memory locations, so the total memory size is 16 × 4 = 64 bytes. To address 64 bytes, we need 6 address bits [5:0]. 
//The lower 2 bits [1:0] represent the byte position inside a 32-bit word. Since this design accepts only word-aligned addresses such as 0, 4, 8, 12, ..., the lower 2 bits are always 00, so we ignore them. 
//The remaining 4 bits [5:2] are used to select one of the 16 memory locations, mem[0] to mem[15].The remaining 4 bits are used to select the starting address of the mem like 0,4,8,12,... 


localparam NUM_WORDS   = 16;            //It defines the number of memory locations (words) in your slave.
localparam ADDR_HI_BIT = 5;             
localparam ADDR_LO_BIT = 2;
 
localparam RESP_OKAY   = 2'b00;          //successful transaction.
localparam RESP_SLVERR = 2'b10;          //Error Response.
 
reg [31:0] mem [15:0];
integer i;
 

function addr_ok(input [31:0] byte_addr);                               
   begin
      addr_ok = (byte_addr[1:0] == 2'b00) && (byte_addr < (NUM_WORDS * 4));     
   end
endfunction
 
// =====================================================================
// WRITE CHANNEL  -- fully independent of the Read channel/state.
// =====================================================================

localparam WIDLE    = 0,
           WCOMPUTE = 1,
           WRESP    = 2;   

reg [1:0]  wstate;
reg        aw_hs_done,                       //Indicates that the write address has been captured
reg         w_hs_done;                       //Indicates that the write data has been captured 
reg [31:0] waddr_r, wdata_r;
reg [3:0]  wstrb_r;
reg        waddr_valid_r;
 
always @(posedge s_axi_aclk) 
begin
  
  if (!s_axi_aresetn) 
  begin
    for (i = 0; i < 16; i = i + 1)  mem[i] <= 32'h0;
    
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

  end 
  
  else 
  begin
    case (wstate)
 
      WIDLE: 
      begin
        // Accept AW independently of W
        if (s_axi_awvalid && !aw_hs_done) 
        begin
          s_axi_awready <= 1'b1;
          waddr_r       <= s_axi_awaddr;
          aw_hs_done    <= 1'b1;
        end 

        else 
        begin
          s_axi_awready <= 1'b0;
        end
 
        // Accept W independently of AW
        if (s_axi_wvalid && !w_hs_done) 
        begin
          s_axi_wready <= 1'b1;
          wdata_r      <= s_axi_wdata;
          wstrb_r      <= s_axi_wstrb;
          w_hs_done    <= 1'b1;
        end 

        else 
        begin
          s_axi_wready <= 1'b0;
        end
 
        // Move on once both sides have completed their handshake
        // (covers AW-first, W-first, and simultaneous arrival)
        if ((aw_hs_done || (s_axi_awvalid && !aw_hs_done))   &&   (w_hs_done  || (s_axi_wvalid  && !w_hs_done)))
          wstate <= WCOMPUTE;
      end
 
      WCOMPUTE: 
      begin
        s_axi_awready <= 1'b0;
        s_axi_wready  <= 1'b0;
        waddr_valid_r <= addr_ok(waddr_r);                  //The received address is acceptable/valid for my memory.
 
        if (addr_ok(waddr_r))                               //mem[waddr_r[5:2]] selects which of the 16 memory locations to write.
        begin
          mem[waddr_r[ADDR_HI_BIT:ADDR_LO_BIT]][7:0]   <= wstrb_r[0] ? wdata_r[7:0]   : mem[waddr_r[ADDR_HI_BIT:ADDR_LO_BIT]][7:0];          
          mem[waddr_r[ADDR_HI_BIT:ADDR_LO_BIT]][15:8]  <= wstrb_r[1] ? wdata_r[15:8]  : mem[waddr_r[ADDR_HI_BIT:ADDR_LO_BIT]][15:8];
          mem[waddr_r[ADDR_HI_BIT:ADDR_LO_BIT]][23:16] <= wstrb_r[2] ? wdata_r[23:16] : mem[waddr_r[ADDR_HI_BIT:ADDR_LO_BIT]][23:16];
          mem[waddr_r[ADDR_HI_BIT:ADDR_LO_BIT]][31:24] <= wstrb_r[3] ? wdata_r[31:24] : mem[waddr_r[ADDR_HI_BIT:ADDR_LO_BIT]][31:24];
        end
 
        wstate <= WRESP;
      end
 
      WRESP: 
      begin
        s_axi_bvalid <= 1'b1;
        s_axi_bresp  <= waddr_valid_r ? RESP_OKAY : RESP_SLVERR;
        
        if (s_axi_bvalid && s_axi_bready) 
        begin
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
 
always @(posedge s_axi_aclk) 
begin
  if (!s_axi_aresetn) 
  begin
    rstate        <= RIDLE;
    s_axi_arready <= 1'b0;
    s_axi_rvalid  <= 1'b0;
    s_axi_rdata   <= 32'h0;
    s_axi_rresp   <= RESP_OKAY;
    raddr_r       <= 32'h0;
    rdata_r       <= 32'h0;
    raddr_valid_r <= 1'b0;
  end 
  
  else 
  begin
    case (rstate)
 
      RIDLE: 
      begin
        if (s_axi_arvalid) 
        begin
          s_axi_arready <= 1'b1;
          raddr_r       <= s_axi_araddr;
          rstate        <= RFETCH;
        end 
        
        else 
        begin
          s_axi_arready <= 1'b0;
        end
      end
 
      RFETCH: 
      begin
        s_axi_arready <= 1'b0;
        raddr_valid_r <= addr_ok(raddr_r);
        rdata_r       <= addr_ok(raddr_r) ? mem[raddr_r[ADDR_HI_BIT:ADDR_LO_BIT]] : 32'h0;
        rstate        <= RRESP;
      end
 
      RRESP: 
      begin
        s_axi_rvalid <= 1'b1;
        s_axi_rdata  <= raddr_valid_r ? rdata_r : 32'h0;
        s_axi_rresp  <= raddr_valid_r ? RESP_OKAY : RESP_SLVERR;
    
        if (s_axi_rvalid && s_axi_rready) 
        begin
          s_axi_rvalid <= 1'b0;
          rstate       <= RIDLE;
        end
      end
 
      default: rstate <= RIDLE;
    endcase
  end
end
 
endmodule
