`include "common_cells/registers.svh"

module user_rom #(
  parameter obi_pkg::obi_cfg_t ObiCfg = obi_pkg::ObiDefaultConfig,
  parameter type obi_req_t = logic,
  parameter type obi_rsp_t = logic
) (
  input  logic    clk_i,
  input  logic    rst_ni,
  
  // OBI Interface (identical to original)
  input  obi_req_t obi_req_i,
  output obi_rsp_t obi_rsp_o,

  // New accelerator port
  input  logic        accel_req_i,
  input  logic [31:0] accel_addr_i,
  output logic [7:0]  accel_data_o,
  output logic        accel_valid_o
);

  // ROM contents (16x16 image = 256 bytes)
  logic [7:0] rom [0:255];  // Matches original style but larger

  // Initialization pattern (like original but extended)
  initial begin
    for (int i = 0; i < 256; i++) begin
      rom[i] = i % 16;  // Simple repeating pattern
    end
  end

  // ---------------------------------------------------------------------------
  // OBI Interface (identical structure to original)
  // ---------------------------------------------------------------------------
  logic req_d, req_q;
  logic we_d, we_q;
  logic [ObiCfg.AddrWidth-1:0] addr_d, addr_q;
  logic [ObiCfg.IdWidth-1:0] id_d, id_q;

  assign req_d = obi_req_i.req;
  assign id_d = obi_req_i.a.aid;
  assign we_d = obi_req_i.a.we;
  assign addr_d = obi_req_i.a.addr;

  // Original pipeline registers
  `FF(req_q, req_d, '0);
  `FF(id_q, id_d, '0);
  `FF(we_q, we_d, '0);
  `FF(addr_q, addr_d, '0);

  // Response generation (same structure)
  logic [31:0] rsp_data;
  logic rsp_err;
  logic [1:0] word_addr;

  always_comb begin
    rsp_data = '0;
    rsp_err = '0;
    word_addr = addr_q[3:2];  // Still using word addressing

    if(req_q) begin
      if(~we_q) begin
        // Now returns actual image data
        rsp_data = {24'h0, rom[addr_q]}; 
      end else begin
        rsp_err = '1;  // Writes still not allowed
      end
    end
  end

  // Original OBI response wiring
  assign obi_rsp_o.gnt = obi_req_i.req;
  assign obi_rsp_o.rvalid = req_q;
  assign obi_rsp_o.r.rdata = rsp_data;
  assign obi_rsp_o.r.rid = id_q;
  assign obi_rsp_o.r.err = rsp_err;
  assign obi_rsp_o.r.r_optional = '0;

  // ---------------------------------------------------------------------------
  // New Accelerator Interface (minimal addition)
  // ---------------------------------------------------------------------------
  `FF(accel_data_o, rom[accel_addr_i[7:0]], '0);  // Simple 8-bit address
  `FF(accel_valid_o, accel_req_i, '0);

endmodule