`include "common_cells/registers.svh"

module user_edge_detect #(
  parameter obi_pkg::obi_cfg_t ObiCfg = obi_pkg::ObiDefaultConfig,
  parameter type obi_req_t = logic,
  parameter type obi_rsp_t = logic
)(
  input  logic clk_i,
  input  logic rst_ni,

  // OBI Slave Interface
  input  obi_req_t obi_req_i,
  output obi_rsp_t obi_rsp_o,

  // ROM Access Interface
  output logic        rom_req_o,
  output logic [31:0] rom_addr_o,
  input  logic [7:0]  rom_data_i,
  input  logic        rom_valid_i
);

  typedef enum logic [1:0] {
    IDLE,
    FETCH,
    COMPUTE,
    DONE
  } state_e;

  state_e state_q, state_d;

  logic req_d, req_q;
  logic we_d, we_q;
  logic [ObiCfg.AddrWidth-1:0] addr_d, addr_q;
  logic [ObiCfg.IdWidth-1:0] id_d, id_q;
  logic [ObiCfg.DataWidth-1:0] wdata_d, wdata_q;

  logic [7:0] pixel_buf[0:8];  // 3x3 window
  logic [3:0] fetch_idx_q, fetch_idx_d;

  logic signed [10:0] gx, gy;
  logic [10:0] abs_gx, abs_gy;
  logic [15:0] edge_sum_d, edge_sum_q;

  // Response signals
  logic [31:0] rsp_data;
  logic rsp_err;

  // Registering inputs
  `FF(req_q, req_d, '0)
  `FF(we_q, we_d, '0)
  `FF(addr_q, addr_d, '0)
  `FF(id_q, id_d, '0)
  `FF(wdata_q, wdata_d, '0)
  `FF(fetch_idx_q, fetch_idx_d, 4'd0)
  `FF(edge_sum_q, edge_sum_d, 16'd0)
  `FF(state_q, state_d, IDLE)

  assign req_d   = obi_req_i.req;
  assign we_d    = obi_req_i.a.we;
  assign addr_d  = obi_req_i.a.addr;
  assign id_d    = obi_req_i.a.aid;
  assign wdata_d = obi_req_i.a.wdata;

  // ROM access
  assign rom_req_o  = (state_q == FETCH);
  assign rom_addr_o = fetch_idx_q;

  // FSM
  always_comb begin
    state_d = state_q;
    fetch_idx_d = fetch_idx_q;
    edge_sum_d = edge_sum_q;

    if (state_q == IDLE && req_q && we_q && addr_q[3:2] == 2'd1) begin
      // Start trigger on write to addr 0x4
      state_d = FETCH;
      fetch_idx_d = 0;
    end

    if (state_q == FETCH && rom_valid_i) begin
      pixel_buf[fetch_idx_q] = rom_data_i;
      if (fetch_idx_q == 8) begin
        state_d = COMPUTE;
      end else begin
        fetch_idx_d = fetch_idx_q + 1;
      end
    end

    if (state_q == COMPUTE) begin
      // Sobel Gx
      gx = -pixel_buf[0] + pixel_buf[2]
         - (pixel_buf[3] << 1) + (pixel_buf[5] << 1)
         - pixel_buf[6] + pixel_buf[8];

      // Sobel Gy
      gy = -pixel_buf[0] - (pixel_buf[1] << 1) - pixel_buf[2]
         + pixel_buf[6] + (pixel_buf[7] << 1) + pixel_buf[8];

      abs_gx = (gx < 0) ? -gx : gx;
      abs_gy = (gy < 0) ? -gy : gy;

      edge_sum_d = abs_gx + abs_gy;
      state_d = DONE;
    end

    if (state_q == DONE && req_q && !we_q && addr_q[3:2] == 2'd1) begin
      // Read edge result
      state_d = IDLE;
    end
  end

  // Response generation
  always_comb begin
    rsp_data = 32'h0;
    rsp_err  = 1'b0;

    if (req_q) begin
      unique case (addr_q[3:2])
        2'd1: begin
          // Edge result
          if (we_q)
            rsp_err = 1'b1;
          else
            rsp_data = {16'h0000, edge_sum_q};
        end
        2'd2: begin
          // Status bit: bit 0 = done
          if (we_q)
            rsp_err = 1'b1;
          else
            rsp_data = {31'b0, (state_q == DONE)};
        end
        default: begin
          rsp_err = 1'b1;
        end
      endcase
    end
  end

  // OBI response
  assign obi_rsp_o.gnt          = obi_req_i.req;
  assign obi_rsp_o.rvalid       = req_q;
  assign obi_rsp_o.r.rdata      = rsp_data;
  assign obi_rsp_o.r.rid        = id_q;
  assign obi_rsp_o.r.err        = rsp_err;
  assign obi_rsp_o.r.r_optional = '0;

endmodule
