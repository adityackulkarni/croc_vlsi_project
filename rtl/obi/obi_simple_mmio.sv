// SPDX-License-Identifier: SHL-0.51
// Simple OBI MMIO register interface
// Maps start (write-only), done, and match (read-only) bits as MMIO registers

module obi_simple_mmio #(
  parameter int unsigned DataWidth = 32
)(
  input  logic               clk_i,
  input  logic               rst_ni,
  
  // OBI interface
  input  sbr_obi_req_t       obi_req_i,
  output sbr_obi_rsp_t       obi_rsp_o,

  // MMIO control signals
  output logic               start_o,  // write-only (bit 0)
  input  logic               done_i,   // read-only (bit 1)
  input  logic               match_i   // read-only (bit 2)
);

  import user_pkg::*;

  // Internal register to hold start bit (set on write, cleared by software or auto-clear on write=0)
  logic start_reg;

  // Default outputs
  assign start_o = start_reg;

  // OBI response signals
  sbr_obi_rsp_t rsp;
  assign obi_rsp_o = rsp;

  // Capture OBI transactions
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      start_reg <= 1'b0;
    end else begin
      if (obi_req_i.vld && obi_req_i.a.we) begin
        // Write transaction: only bit 0 affects start register
        start_reg <= obi_req_i.a.wdata[0];
      end
      // Optionally, you can auto-clear start_reg here or keep it set until cleared by software
    end
  end

  // Formulate OBI response
  always_comb begin
    rsp.vld   = obi_req_i.vld;
    rsp.error = 1'b0;
    rsp.rdata = '0;

    if (obi_req_i.vld && !obi_req_i.a.we) begin
      // Read transaction: provide done and match in bits 1 and 2
      rsp.rdata = {29'd0, match_i, done_i, 1'b0};
      // bit0 is zero on read, bit1=done, bit2=match
    end
  end

endmodule
