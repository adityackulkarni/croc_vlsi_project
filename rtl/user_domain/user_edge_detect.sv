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
  output obi_rsp_t obi_rsp_o
);

  typedef enum logic [1:0] {
    IDLE,
    COMPUTE,
    DONE
  } state_e;

  state_e state_q, state_d;

  logic req_d, req_q;
  logic we_d, we_q;
  logic [ObiCfg.AddrWidth-1:0] addr_d, addr_q;
  logic [ObiCfg.IdWidth-1:0] id_d, id_q;
  logic [ObiCfg.DataWidth-1:0] wdata_d, wdata_q;

  // Storage for 9 pixels (3x3)
  logic [7:0] pixels[0:8];

  logic [15:0] edge_sum_d, edge_sum_q;

  // Control signals
  logic start_d, start_q;
  logic done_d, done_q;

  // Response signals
  logic [31:0] rsp_data;
  logic rsp_err;

  // Register inputs
  `FF(req_q, req_d, '0)
  `FF(we_q, we_d, '0)
  `FF(addr_q, addr_d, '0)
  `FF(id_q, id_d, '0)
  `FF(wdata_q, wdata_d, '0)
  `FF(edge_sum_q, edge_sum_d, 16'd0)
  `FF(state_q, state_d, IDLE)
  `FF(start_q, start_d, 1'b0)
  `FF(done_q, done_d, 1'b0)

  assign req_d   = obi_req_i.req;
  assign we_d    = obi_req_i.a.we;
  assign addr_d  = obi_req_i.a.addr;
  assign id_d    = obi_req_i.a.aid;
  assign wdata_d = obi_req_i.a.wdata;

  // FSM
  always_comb begin
    state_d = state_q;
    edge_sum_d = edge_sum_q;
    start_d = start_q;
    done_d = done_q;
    rsp_err = 1'b0;
    rsp_data = 32'h0;

    if (req_q) begin
      if (we_q) begin
        // Writes
        unique case (addr_q[7:0])  // check lower bits as needed
          // Writing pixels at offsets 0x0, 0x4, 0x8, ..., 0x20 (9 words)
          8'h00,8'h04,8'h08,8'h0C,8'h10,8'h14,8'h18,8'h1C,8'h20: begin
            pixels[addr_q[5:2]] = wdata_q[7:0]; // store lower byte only
            start_d = 1'b0; // reset start on pixel write
            done_d = 1'b0;  // clear done on new input
          end

          8'h24: begin
            // Start signal write
            if (wdata_q[0]) begin
              if (state_q == IDLE) begin
                start_d = 1'b1;
                done_d = 1'b0;
                state_d = COMPUTE;
              end
            end
          end

          default: rsp_err = 1'b1;
        endcase
      end else begin
        // Reads
        unique case (addr_q[7:0])
          8'h04: begin
            // Edge result read
            rsp_data = {16'd0, edge_sum_q};
          end
          8'h28: begin
            // Status read - bit 0 is done
            rsp_data = {31'd0, done_q};
          end
          default: rsp_err = 1'b1;
        endcase
      end
    end

    // Compute edge when state is COMPUTE
    if (state_q == COMPUTE) begin
      // Sobel Gx
      logic signed [10:0] gx, gy;
      logic [10:0] abs_gx, abs_gy;

      gx = -pixels[0] + pixels[2]
         - (pixels[3] << 1) + (pixels[5] << 1)
         - pixels[6] + pixels[8];

      gy = -pixels[0] - (pixels[1] << 1) - pixels[2]
         + pixels[6] + (pixels[7] << 1) + pixels[8];

      abs_gx = (gx < 0) ? -gx : gx;
      abs_gy = (gy < 0) ? -gy : gy;

      edge_sum_d = abs_gx + abs_gy;

      done_d = 1'b1;
      start_d = 1'b0;
      state_d = DONE;
    end

    if (state_q == DONE && req_q && !we_q && addr_q[7:0] == 8'h28) begin
      // Status read acknowledged
      done_d = done_q;
    end

    if (state_q == DONE && !start_q) begin
      state_d = IDLE;
      done_d = 1'b0;
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
