// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

`include "common_cells/registers.svh"

module user_edge_detect #(
  parameter obi_pkg::obi_cfg_t           ObiCfg      = obi_pkg::ObiDefaultConfig,
  parameter type                         obi_req_t   = logic,
  parameter type                         obi_rsp_t   = logic
) (
  input  logic clk_i,
  input  logic rst_ni,

  input  obi_req_t obi_req_i,
  output obi_rsp_t obi_rsp_o
);

  // Request registers (1 cycle delay)
  logic req_d, req_q;
  logic we_d, we_q;
  logic [ObiCfg.AddrWidth-1:0] addr_d, addr_q;
  logic [ObiCfg.IdWidth-1:0] id_d, id_q;
  logic [ObiCfg.DataWidth-1:0] wdata_d, wdata_q;

  // Response registers (to delay rvalid by 1 cycle)
  logic rvalid_d, rvalid_q;

  // Response data and error
  logic [ObiCfg.DataWidth-1:0] rsp_data;
  logic rsp_err;

  // Accumulator registers
  logic [15:0] set_bits_accumulator_d, set_bits_accumulator_q;
  logic [15:0] wdata_cnt;

  // Flip-flops for request and accumulator registers
  `FF(req_q, req_d, '0);
  `FF(id_q , id_d , '0);
  `FF(we_q , we_d , '0);
  `FF(wdata_q , wdata_d , '0);
  `FF(addr_q , addr_d , '0);
  `FF(set_bits_accumulator_q, set_bits_accumulator_d, '0);

  // Flip-flop for delayed rvalid
  `FF(rvalid_q, rvalid_d, 1'b0);

  // Latch inputs
  assign req_d = obi_req_i.req;
  assign id_d = obi_req_i.a.aid;
  assign we_d = obi_req_i.a.we;
  assign addr_d = obi_req_i.a.addr;
  assign wdata_d = obi_req_i.a.wdata;

  // Count number of set bits in previous wdata
  always_comb begin
    wdata_cnt = 0;
    for (int i = 0; i < 32; i++)
      if (wdata_q[i]) wdata_cnt += 1;
  end

  // Default assignments
  always_comb begin
    rsp_data = '0;
    rsp_err = '0;
    set_bits_accumulator_d = set_bits_accumulator_q;

    if (req_q) begin
      case (addr_q[3:2])
        2'h0: begin
          if (we_q) begin
            // Write 0 to accumulator
            set_bits_accumulator_d = '0;
          end else begin
            rsp_err = 1'b1;
          end
        end

        2'h1: begin
          if (we_q) begin
            // Add bit count of previous wdata to accumulator
            set_bits_accumulator_d = set_bits_accumulator_q + wdata_cnt;
          end else begin
            rsp_err = 1'b1;
          end
        end

        2'h2: begin
          if (we_q) begin
            rsp_err = 1'b1;
          end else begin
            // Read accumulator value
            rsp_data = {16'b0, set_bits_accumulator_q};
          end
        end

        default: rsp_data = 32'hffffffff;
      endcase
    end
  end

  // Delay rvalid by one cycle to meet OBI protocol timing
  always_comb begin
    rvalid_d = req_q;
  end

  // OBI response signals
  assign obi_rsp_o.gnt = obi_req_i.req;
  assign obi_rsp_o.rvalid = rvalid_q;
  assign obi_rsp_o.r.rdata = rsp_data;
  assign obi_rsp_o.r.rid = id_q;
  assign obi_rsp_o.r.err = rsp_err;
  assign obi_rsp_o.r.r_optional = '0;

endmodule
