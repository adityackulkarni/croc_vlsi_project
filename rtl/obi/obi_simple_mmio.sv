module obi_simple_mmio #(
  parameter logic [31:0] BASE_ADDR = 32'h2000_0000,
  parameter logic [31:0] END_ADDR  = 32'h2000_0FFF
)(
  input  logic        clk_i,
  input  logic        rst_ni,

  // Flattened OBI interface (Subordinate)
  input  logic        req_i,
  input  logic [31:0] addr_i,
  input  logic        we_i,
  input  logic [3:0]  be_i,
  input  logic [31:0] wdata_i,
  output logic        gnt_o,

  output logic        rvalid_o,
  output logic [31:0] rdata_o,
  output logic        err_o,
  input  logic        rready_i,

  // MMIO control interface
  output logic        start,
  input  logic        done,
  input  logic        match
);

  // Local registers
  logic [31:0] accel_start_reg;
  logic [31:0] accel_done_reg;
  logic [31:0] accel_match_reg;

  // Address decode
  logic is_accel_start = (addr_i == BASE_ADDR + 32'h00);
  logic is_accel_done  = (addr_i == BASE_ADDR + 32'h04);
  logic is_accel_match = (addr_i == BASE_ADDR + 32'h08);

  // Grant logic (combinational grant when in region)
  assign gnt_o = req_i && ((addr_i >= BASE_ADDR) && (addr_i <= END_ADDR));

  // Write handling
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      accel_start_reg <= 32'b0;
    end else if (req_i && we_i && gnt_o) begin
      if (is_accel_start) begin
        accel_start_reg <= wdata_i;
      end
    end
  end

  // Start signal (pulse)
  assign start = accel_start_reg[0];

  // Read handling
  always_comb begin
    rvalid_o = 1'b0;
    rdata_o  = 32'b0;
    err_o    = 1'b0;

    if (req_i && !we_i && gnt_o) begin
      rvalid_o = 1'b1;
      if (is_accel_start)
        rdata_o = accel_start_reg;
      else if (is_accel_done)
        rdata_o = done;
      else if (is_accel_match)
        rdata_o = match;
      else
        err_o = 1'b1;
    end
  end

endmodule
