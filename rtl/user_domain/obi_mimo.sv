module obi_mimo (
  input  logic         clk,
  input  logic         rst_n,

  // Accelerator interface
  input  logic         read_req,
  input  logic         write_req,
  input  logic [31:0]  addr,
  input  logic [31:0]  wdata,
  output logic         read_done,
  output logic         write_done,
  output logic [31:0]  rdata,

  // OBI A channel
  output logic         obi_req,
  input  logic         obi_gnt,
  output logic [31:0]  obi_addr,
  output logic         obi_we,
  output logic [3:0]   obi_be,
  output logic [31:0]  obi_wdata,
  output logic [3:0]   obi_aid,

  // OBI R channel
  input  logic         obi_rvalid,
  input  logic [31:0]  obi_rdata,
  input  logic         obi_err,
  input  logic [3:0]   obi_rid
);

  typedef enum logic [1:0] {
    IDLE, ADDR_PHASE, WAIT_RESP
  } state_t;

  state_t state, next_state;

  logic is_read;

  // Registers to hold input
  logic [31:0] addr_reg, wdata_reg;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      addr_reg   <= 0;
      wdata_reg  <= 0;
    end else begin
      state <= next_state;
      if (state == IDLE && (read_req || write_req)) begin
        addr_reg  <= addr;
        wdata_reg <= wdata;
      end
    end
  end

  always_comb begin
    next_state = state;
    case (state)
      IDLE:
        if (read_req || write_req) next_state = ADDR_PHASE;

      ADDR_PHASE:
        if (obi_gnt) next_state = WAIT_RESP;

      WAIT_RESP:
        if (obi_rvalid) next_state = IDLE;
    endcase
  end

  // Output signals
  assign obi_req    = (state == ADDR_PHASE);
  assign obi_addr   = addr_reg;
  assign obi_we     = write_req;
  assign obi_be     = 4'b1111;
  assign obi_wdata  = wdata_reg;
  assign obi_aid    = 4'b0001;

  assign read_done  = (state == WAIT_RESP) && obi_rvalid && !write_req;
  assign write_done = (state == WAIT_RESP) && obi_rvalid && write_req;
  assign rdata      = obi_rdata;

endmodule
