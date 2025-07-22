// New
`include "common_cells/registers.svh"

// simple ROM
module user_rom #(
  /// The OBI configuration for all ports.
  parameter obi_pkg::obi_cfg_t           ObiCfg      = obi_pkg::ObiDefaultConfig,
  /// The request struct.
  parameter type                         obi_req_t   = logic,
  /// The response struct.
  parameter type                         obi_rsp_t   = logic
) (
  /// Clock
  input  logic clk_i,
  /// Active-low reset
  input  logic rst_ni,

// OBI Subordinate Interface

  /// OBI request interface
  input  obi_req_t obi_req_i,
  /// OBI response interface
  output obi_rsp_t obi_rsp_o,

// Accelerator Interface
  input  logic        accel_req_i,
  input  logic [31:0] accel_addr_i,
  output logic [7:0]  accel_data_o,
  output logic        accel_valid_o,
);

  // ---------------------------------------------------------------------------
  // ROM contents
  // ---------------------------------------------------------------------------

  logic [7:0] rom [0:15];  // 16 bytes (4 words)
  initial begin
    rom[0]  = 8'h01; rom[1]  = 8'h02; rom[2]  = 8'h03; rom[3]  = 8'h04;
    rom[4]  = 8'h05; rom[5]  = 8'h06; rom[6]  = 8'h07; rom[7]  = 8'h08;
    rom[8]  = 8'h09; rom[9]  = 8'h0A; rom[10] = 8'h0B; rom[11] = 8'h0C;
    rom[12] = 8'h0D; rom[13] = 8'h0E; rom[14] = 8'h0F; rom[15] = 8'h10;
  end

  // ---------------------------------------------------------------------------
  // OBI Request Pipeline (2-cycle response latency)
  // ---------------------------------------------------------------------------

  // Define some registers to hold the requests fields
  logic req_d, req_q, req_q2; // Request valid
  logic we_d, we_q, we_q2; // Write enable
  logic [ObiCfg.AddrWidth-1:0] addr_d, addr_q, addr_q2; // Internal address of the word to read
  logic [ObiCfg.IdWidth-1:0] id_d, id_q, id_q2; // Id of the request, must be same for the response

  // Wire the registers holding the request
  // The code such that the ROM will respond after 2 cycles instead of 1
  assign req_d = obi_req_i.req;
  assign id_d = obi_req_i.a.aid;
  assign we_d = obi_req_i.a.we;
  assign addr_d = obi_req_i.a.addr;

  always_ff @(posedge (clk_i) or negedge (rst_ni)) begin
    if (!rst_ni) begin
      req_q <= '0;
      id_q <= '0;
      we_q <= '0;
      addr_q <= '0;
      req_q2 <= '0;
      id_q2 <= '0;
      we_q2 <= '0;
      addr_q2 <= '0;
    end else begin
      req_q <= req_d;
      id_q <= id_d;
      we_q <= we_d;
      addr_q <= addr_d;
      req_q2 <= req_q;
      id_q2 <= id_q;
      we_q2 <= we_q;
      addr_q2 <= addr_q;
    end
  end

  // ---------------------------------------------------------------------------
  // OBI Response Generation
  // ---------------------------------------------------------------------------

  // Assign the response data
  
  logic [31:0] rsp_data;
  logic rsp_err;
  
  always_comb begin
    rsp_data = 32'h0;
    rsp_err  = 1'b0;

    if (req_q2 && ~we_q2) begin
      // Word-aligned access
      rsp_data = {
        rom[{addr_q2[3:2], 2'b11}],
        rom[{addr_q2[3:2], 2'b10}],
        rom[{addr_q2[3:2], 2'b01}],
        rom[{addr_q2[3:2], 2'b00}]
      };
    end else if (req_q2 && we_q2) begin
      rsp_err = 1'b1;  // Writes not supported
    end
  end

  // Wire the response
  // A channel
  assign obi_rsp_o.gnt = obi_req_i.req;
  // R channel:
  assign obi_rsp_o.rvalid = req_q2;
  assign obi_rsp_o.r.rdata = rsp_data;
  assign obi_rsp_o.r.rid = id_q2;
  assign obi_rsp_o.r.err = rsp_err;
  assign obi_rsp_o.r.r_optional = '0;

  // ---------------------------------------------------------------------------
  // Accelerator Read Port (8-bit addressable)
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      accel_data_o  <= '0;
      accel_valid_o <= 1'b0;
    end else begin
      if (accel_req_i && accel_addr_i < 16) begin
        accel_data_o  <= rom[accel_addr_i[3:0]];  // 4-bit address: 0–15
        accel_valid_o <= 1'b1;
      end else begin
        accel_data_o  <= 8'h00;
        accel_valid_o <= 1'b0;
      end
    end
  end

endmodule