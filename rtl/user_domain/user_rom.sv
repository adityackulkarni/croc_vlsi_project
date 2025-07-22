// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Philippe Sauter <phsauter@iis.ee.ethz.ch>

`include "common_cells/registers.svh"

module user_rom #(
  parameter obi_pkg::obi_cfg_t ObiCfg    = obi_pkg::ObiDefaultConfig,
  parameter type               obi_req_t = logic,
  parameter type               obi_rsp_t = logic
)(
  input  logic clk_i,
  input  logic rst_ni,

  // OBI Subordinate Interface
  input  obi_req_t obi_req_i,
  output obi_rsp_t obi_rsp_o,

  // Accelerator Interface
  input  logic        accel_req_i,
  input  logic [31:0] accel_addr_i,
  output logic [7:0]  accel_data_o
);

  // ---------------------------------------------------------------------------
  // ROM contents
  // ---------------------------------------------------------------------------
  logic [7:0] rom [0:15];

  initial begin
    rom[ 0] = 8'h01; rom[ 1] = 8'h02; rom[ 2] = 8'h03; rom[ 3] = 8'h04;
    rom[ 4] = 8'h05; rom[ 5] = 8'h06; rom[ 6] = 8'h07; rom[ 7] = 8'h08;
    rom[ 8] = 8'h09; rom[ 9] = 8'h0A; rom[10] = 8'h0B; rom[11] = 8'h0C;
    rom[12] = 8'h0D; rom[13] = 8'h0E; rom[14] = 8'h0F; rom[15] = 8'h10;
  end

  // ---------------------------------------------------------------------------
  // OBI Request Pipeline (2-cycle response latency)
  // ---------------------------------------------------------------------------
  logic req_q,  req_q2;
  logic we_q,   we_q2;
  logic [ObiCfg.AddrWidth-1:0] addr_q, addr_q2;
  logic [ObiCfg.IdWidth-1:0]   id_q,   id_q2;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      req_q   <= 1'b0;
      we_q    <= 1'b0;
      addr_q  <= '0;
      id_q    <= '0;

      req_q2  <= 1'b0;
      we_q2   <= 1'b0;
      addr_q2 <= '0;
      id_q2   <= '0;
    end else begin
      req_q   <= obi_req_i.req;
      we_q    <= obi_req_i.a.we;
      addr_q  <= obi_req_i.a.addr;
      id_q    <= obi_req_i.a.aid;

      req_q2  <= req_q;
      we_q2   <= we_q;
      addr_q2 <= addr_q;
      id_q2   <= id_q;
    end
  end

  // ---------------------------------------------------------------------------
  // OBI Response Generation
  // ---------------------------------------------------------------------------
  logic [31:0] rsp_data;
  logic        rsp_err;

  always_comb begin
    rsp_data = 32'h0;
    rsp_err  = 1'b0;

    if (req_q2 && ~we_q2) begin
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

  assign obi_rsp_o.gnt        = obi_req_i.req;
  assign obi_rsp_o.rvalid     = req_q2;
  assign obi_rsp_o.r.rdata    = rsp_data;
  assign obi_rsp_o.r.rid      = id_q2;
  assign obi_rsp_o.r.err      = rsp_err;
  assign obi_rsp_o.r.r_optional = '0;

  // ---------------------------------------------------------------------------
  // Accelerator 8-bit read-only interface
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      accel_data_o <= 8'h00;
    end else begin
      if (accel_req_i && accel_addr_i < 16)
        accel_data_o <= rom[accel_addr_i[3:0]];
      else
        accel_data_o <= 8'h00;
    end
  end

endmodule
