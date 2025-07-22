`include "common_cells/registers.svh"
`include "obi/typedef.svh"

module user_edge_detect #(
  parameter obi_pkg::obi_cfg_t ObiCfg = obi_pkg::ObiDefaultConfig,
  parameter type obi_req_t = logic,
  parameter type obi_rsp_t = logic
) (
  input  logic                  clk_i,
  input  logic                  rst_ni,

  input  obi_req_t              obi_req_i,
  output obi_rsp_t              obi_rsp_o
);

  // Internal registers for OBI request fields
  logic req_d, req_q;
  logic we_d, we_q;
  logic [ObiCfg.AddrWidth-1:0] addr_d, addr_q;
  logic [ObiCfg.IdWidth-1:0]   id_d, id_q;
  logic [ObiCfg.DataWidth-1:0] wdata_d, wdata_q;

  `FF(req_q, req_d, '0);
  `FF(we_q, we_d, '0);
  `FF(addr_q, addr_d, '0);
  `FF(id_q, id_d, '0);
  `FF(wdata_q, wdata_d, '0);

  assign req_d = obi_req_i.req;
  assign we_d = obi_req_i.a.we;
  assign addr_d = obi_req_i.a.addr;
  assign id_d = obi_req_i.a.aid;
  assign wdata_d = obi_req_i.a.wdata;

  // Pixel storage (9 pixels, 8-bit each)
  logic [7:0] pixels [0:8];
  logic [3:0] pixel_count_d, pixel_count_q; // counts pixels written (0..9)
  `FF(pixel_count_q, pixel_count_d, 0);

  // Status and result registers
  logic        busy_d, busy_q;
  logic [7:0]  result_d, result_q;
  `FF(busy_q, busy_d, 0);
  `FF(result_q, result_d, 0);

  // OBI response signals
  logic [ObiCfg.DataWidth-1:0] rsp_data;
  logic rsp_err;

  // Word address decoding (assuming word addressing, bits [3:2] select reg)
  logic [1:0] word_addr = addr_q[3:2];

  // Sobel computation function (8-bit output)
  function automatic [7:0] sobel_compute(input logic [7:0] w[0:8]);
    int gx, gy, g;
    begin
      gx = (-1)*w[0] + 0*w[1] + (1)*w[2]
         + (-2)*w[3] + 0*w[4] + (2)*w[5]
         + (-1)*w[6] + 0*w[7] + (1)*w[8];
      gy = (-1)*w[0] + (-2)*w[1] + (-1)*w[2]
         + 0*w[3] + 0*w[4] + 0*w[5]
         + (1)*w[6] + (2)*w[7] + (1)*w[8];
      g = (gx < 0 ? -gx : gx) + (gy < 0 ? -gy : gy);
      if (g > 255) g = 255;
      return g[7:0];
    end
  endfunction

  // Default assignments
  rsp_data = '0;
  rsp_err = 1'b0;

  // Pixel count next state logic
  if (!rst_ni) begin
    pixel_count_d = 0;
    busy_d = 0;
    result_d = 0;
  end else begin
    pixel_count_d = pixel_count_q;
    busy_d = busy_q;
    result_d = result_q;
  end

  // OBI request handling
  always_comb begin
    rsp_data = 32'hFFFF_FFFF;
    rsp_err = 1'b0;

    if (req_q) begin
      case(word_addr)
        2'b00: begin // 0x0: Pixel input (write only)
          if (we_q) begin
            if (!busy_q) begin
              // Store incoming pixel at current count index
              // Write pixel (lowest 8 bits of wdata_q)
              // We must drive pixels array - needs procedural block, do in always_ff below
              // Here just no read response (write only)
            end else begin
              rsp_err = 1'b1; // busy, cannot write pixels
            end
          end else begin
            rsp_err = 1'b1; // read not allowed
          end
          rsp_data = 32'h0; // dummy data on write
        end
        2'b01: begin // 0x4: Status register (read only)
          if (!we_q) begin
            // bit0 = done (not busy)
            rsp_data = {31'd0, !busy_q};
          end else begin
            rsp_err = 1'b1;
          end
        end
        2'b10: begin // 0x8: Result register (read only)
          if (!we_q) begin
            rsp_data = {24'd0, result_q};
          end else begin
            rsp_err = 1'b1;
          end
        end
        default: begin
          rsp_data = 32'hFFFF_FFFF;
          rsp_err = 1'b1;
        end
      endcase
    end
  end

  // Sequential logic for pixel loading and computation
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      pixel_count_q <= 0;
      busy_q <= 0;
      result_q <= 0;
      for (int i=0; i<9; i++) pixels[i] <= 0;
    end else begin
      if (req_q && we_q && (addr_q[3:2] == 2'b00) && !busy_q) begin
        // Load pixel at current index
        pixels[pixel_count_q] <= wdata_q[7:0];
        pixel_count_q <= pixel_count_q + 1;

        // If 9th pixel written, trigger computation
        if (pixel_count_q == 8) begin
          busy_q <= 1; // busy while computing
          // compute result combinationally next cycle (for simplicity)
          result_q <= sobel_compute(pixels);
          pixel_count_q <= 0;
          busy_q <= 0; // done immediately (can insert delay if needed)
        end
      end
    end
  end

  // OBI response wiring
  assign obi_rsp_o.gnt = obi_req_i.req;
  assign obi_rsp_o.rvalid = req_q;
  assign obi_rsp_o.r.rdata = rsp_data;
  assign obi_rsp_o.r.rid = id_q;
  assign obi_rsp_o.r.err = rsp_err;
  assign obi_rsp_o.r.r_optional = '0;

endmodule
