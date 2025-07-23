// FSM-BASED TOP MODULE FOR IN-PLACE IMAGE THRESHOLDING

`include "common_cells/registers.svh"

module user_top_module #(
  parameter obi_pkg::obi_cfg_t ObiCfg      = obi_pkg::ObiDefaultConfig,
  parameter type               sbr_obi_req_t   = logic,
  parameter type               sbr_obi_rsp_t   = logic,

  parameter type               mgr_obi_rsp_t   = logic,
  parameter type               mgr_obi_req_t   = logic,
) (
  input  logic clk_i,
  input  logic rst_ni,

  input  sbr_obi_req_t obi_sbr_req_i, // from CPU
  input  mgr_obi_rsp_t obi_mgr_rsp_i, // response from SRAM
  output mgr_obi_req_t obi_mgr_req_o, // request to SRAM
  output sbr_obi_rsp_t obi_sbr_rsp_o  // response to CPU
);

// OBI subordinate request latching
logic req_d, req_q;
logic we_d, we_q;
logic [ObiCfg.AddrWidth-1:0] addr_d, addr_q;
logic [ObiCfg.IdWidth-1:0] id_d, id_q;
logic [ObiCfg.DataWidth-1:0] wdata_d, wdata_q;

`FF(req_q, req_d, '0);
`FF(id_q , id_d , '0);
`FF(we_q , we_d , '0);
`FF(wdata_q , wdata_d , '0);
`FF(addr_q , addr_d , '0);

assign req_d    = obi_sbr_req_i.req;
assign id_d     = obi_sbr_req_i.a.aid;
assign we_d     = obi_sbr_req_i.a.we;
assign addr_d   = obi_sbr_req_i.a.addr;
assign wdata_d  = obi_sbr_req_i.a.wdata;

// FSM States
typedef enum logic [1:0] {
  IDLE,        // Wait for MMIO trigger
  COMPUTE,     // Streamer is busy doing a batch
  REPEAT,      // Wait for valid, update counters
  DONE         // All done
} state_t;


state_t state_q, state_d;
`FF(state_q, state_d, IDLE);

// Thresholding registers
logic [ObiCfg.DataWidth-1:0] threshold_q, threshold_d;
logic [ObiCfg.AddrWidth-1:0] current_addr_q, current_addr_d;
logic [ObiCfg.DataWidth-1:0] img_size_q, img_size_d;
logic [ObiCfg.DataWidth-1:0] pixel_count_q, pixel_count_d;
logic done_q, done_d;

`FF(threshold_q, threshold_d, '0);
`FF(current_addr_q, current_addr_d, '0);
`FF(img_size_q, img_size_d, '0);
`FF(pixel_count_q, pixel_count_d, '0);
`FF(done_q, done_d, 1'b0);

// Module interfacing
logic [31:0] rpixels;
logic is_valid_from_streamer;
logic [31:0] thresholded_pixels;
logic is_req, is_write;

// MMIO write logic + FSM triggers
always_comb begin
  threshold_d     = threshold_q;
  current_addr_d  = current_addr_q;
  img_size_d      = img_size_q;
  pixel_count_d   = pixel_count_q;
  done_d          = done_q;
  state_d         = state_q;

  if (req_q && we_q) begin
    case (addr_q[5:2])
      3'h0: current_addr_d = wdata_q;
      3'h1: threshold_d    = wdata_q[7:0];
      3'h2: if (wdata_q[0]) begin
        pixel_count_d = '0;
        done_d        = 1'b0;
        state_d       = COMPUTE;
      end
      3'h3: img_size_d = wdata_q;
      default: ;
    endcase
  end


  case (state_q)
    IDLE: begin
      state_d = state_q;
    end

    COMPUTE: begin
      if (is_valid_from_streamer) begin
        // streamer finished this transaction
        if (pixel_count_q + 4 >= img_size_q) begin
          done_d = 1'b1;
          state_d = DONE;
        end else begin
          pixel_count_d   = pixel_count_q + 4;
          current_addr_d  = current_addr_q + 1;
          state_d = COMPUTE; // loop again
        end
      end else begin
        state_d = state_q; // stay until streamer finishes
      end
    end

    DONE: state_d = DONE;
    default: state_d = IDLE;
  endcase

end


assign is_req   = (state_q == COMPUTE);
assign is_write = 1'b1; // if always write back after compute

user_obi_streamer #(
  .ObiCfg(MgrObiCfg),
  .obi_req_t(mgr_obi_req_t),
  .obi_rsp_t(mgr_obi_rsp_t)
) u_streamer (
  .clk_i(clk_i),
  .rst_ni(rst_ni),
  .is_req_i(is_req),
  .is_write_i(is_write),
  .rw_addr_i(current_addr_q),
  .wdata_i(thresholded_pixels),
  .rpixels(rpixels),
  .is_valid(is_valid_from_streamer),
  .obi_rsp_i(obi_mgr_rsp_i),
  .obi_req_o(obi_mgr_req_o)
);

user_compute_module u_compute (
  .rpixels(rpixels),
  .is_valid(is_valid_from_streamer),
  .threshold(threshold_q[7:0]),
  .wdata_o(thresholded_pixels)
);

// MMIO readback
logic [ObiCfg.DataWidth-1:0] rsp_data;
logic rsp_err;

always_comb begin
  rsp_data = '0;
  rsp_err  = 1'b0;

  if (req_q && !we_q) begin
    case (addr_q[5:2])
      3'h0: rsp_data = current_addr_q;
      3'h1: rsp_data = {24'b0, threshold_q[7:0]};
      3'h2: rsp_data = 32'hDEADBEEF;
      3'h3: rsp_data = img_size_q;
      3'h4: rsp_data = {31'b0, done_q};
      default: rsp_data = 32'hDEADBEEF;
    endcase
  end
end

assign obi_sbr_rsp_o.gnt      = req_q;
assign obi_sbr_rsp_o.rvalid   = req_q;
assign obi_sbr_rsp_o.r.rdata  = rsp_data;
assign obi_sbr_rsp_o.r.rid    = id_q;
assign obi_sbr_rsp_o.r.err    = rsp_err;
assign obi_sbr_rsp_o.r.r_optional = '0;

endmodule