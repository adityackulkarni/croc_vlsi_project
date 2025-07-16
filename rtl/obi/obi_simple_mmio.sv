module obi_simple_mmio #(
  parameter int DataWidth = 32,
  parameter type obi_req_t = logic,
  parameter type obi_rsp_t = logic
)(
  input  logic clk_i,
  input  logic rst_ni,

  input  obi_req_t obi_req_i,
  output obi_rsp_t obi_rsp_o,

  output logic start_o,
  input  logic done_i,
  input  logic match_i
);

  // MMIO register (only start is writable)
  logic start_reg;
  assign start_o = start_reg;

  // MMIO address map (0 = start, 4 = done, 8 = match)
  localparam START_ADDR = 32'h0;
  localparam DONE_ADDR  = 32'h4;
  localparam MATCH_ADDR = 32'h8;

  logic [DataWidth-1:0] rdata_q;
  logic                 ready_q;

  // MMIO behavior
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      start_reg <= 1'b0;
      rdata_q   <= '0;
      ready_q   <= 1'b0;
    end else begin
      ready_q <= 1'b0;

      if (obi_req_i.req && obi_req_i.we) begin
        // Write access
        if (obi_req_i.addr == START_ADDR)
          start_reg <= obi_req_i.wdata[0]; // Only LSB matters
        ready_q <= 1'b1;

      end else if (obi_req_i.req && !obi_req_i.we) begin
        // Read access
        case (obi_req_i.addr)
          DONE_ADDR:  rdata_q <= {{(DataWidth-1){1'b0}}, done_i};
          MATCH_ADDR: rdata_q <= {{(DataWidth-1){1'b0}}, match_i};
          default:    rdata_q <= '0;
        endcase
        ready_q <= 1'b1;
      end
    end
  end

  assign obi_rsp_o.rvalid = ready_q;
  assign obi_rsp_o.rdata  = rdata_q;

endmodule
