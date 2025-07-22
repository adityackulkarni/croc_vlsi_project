`include "common_cells/registers.svh"

module user_rom #(
  parameter obi_pkg::obi_cfg_t ObiCfg = obi_pkg::ObiDefaultConfig,
  parameter type obi_req_t = logic,
  parameter type obi_rsp_t = logic,
  parameter int IMG_WIDTH = 16,  // Reduced from 64 to 16
  parameter int IMG_HEIGHT = 16  // Reduced from 64 to 16
) (
  input  logic    clk_i,
  input  logic    rst_ni,
  
  // OBI Interface
  input  obi_req_t obi_req_i,
  output obi_rsp_t obi_rsp_o,

  // Accelerator Interface
  input  logic        accel_req_i,
  input  logic [31:0] accel_addr_i,
  output logic [7:0]  accel_data_o,
  output logic        accel_valid_o
);

  // ---------------------------------------------------------------------------
  // ROM Storage (16x16 image = 256 bytes)
  // ---------------------------------------------------------------------------
  localparam DEPTH = IMG_WIDTH * IMG_HEIGHT;
  logic [7:0] image_ram [0:DEPTH-1];

  // Initialize with test pattern (similar to exercise style)
  initial begin
    for (int i = 0; i < DEPTH; i++) begin
      image_ram[i] = i % 16;  // Reduced pattern range
    end
  end

  // ---------------------------------------------------------------------------
  // OBI Interface (2-cycle latency like exercise)
  // ---------------------------------------------------------------------------
  logic req_q, req_qq;
  logic [ObiCfg.AddrWidth-1:0] addr_q, addr_qq;
  logic [ObiCfg.IdWidth-1:0] id_q, id_qq;
  logic we_q, we_qq;

  // First pipeline stage (like user_rom.sv)
  `FF(req_q, obi_req_i.req, '0);
  `FF(id_q, obi_req_i.a.aid, '0);
  `FF(we_q, obi_req_i.a.we, '0);
  `FF(addr_q, obi_req_i.a.addr, '0);

  // Second pipeline stage (for 2-cycle latency)
  `FF(req_qq, req_q, '0);
  `FF(id_qq, id_q, '0);
  `FF(we_qq, we_q, '0);
  `FF(addr_qq, addr_q, '0);

  // OBI Response (similar to exercise)
  logic [31:0] rsp_data;
  always_comb begin
    rsp_data = '0;
    if (req_qq && ~we_qq) begin
      rsp_data = {24'h0, image_ram[addr_qq]}; // Byte access
    end
  end

  assign obi_rsp_o.gnt = obi_req_i.req;
  assign obi_rsp_o.rvalid = req_qq;
  assign obi_rsp_o.r.rdata = rsp_data;
  assign obi_rsp_o.r.rid = id_qq;
  assign obi_rsp_o.r.err = we_qq;
  assign obi_rsp_o.r.r_optional = '0;

  // ---------------------------------------------------------------------------
  // Accelerator Interface (similar to setbitacc)
  // ---------------------------------------------------------------------------
  logic [7:0] accel_data_q;
  logic accel_valid_q;

  `FF(accel_data_o, accel_req_i ? image_ram[accel_addr_i] : '0, '0);
  `FF(accel_valid_o, accel_req_i, '0);

endmodule