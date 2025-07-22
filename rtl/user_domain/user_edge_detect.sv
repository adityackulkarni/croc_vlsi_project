module user_edge_detect #(
  parameter type obi_req_t  = logic,
  parameter type obi_rsp_t  = logic,
  parameter type ObiCfg     = logic
)(
  input  logic clk_i,
  input  logic rst_ni,

  // OBI slave interface from CPU
  input  obi_req_t  obi_req_i,
  output obi_rsp_t  obi_rsp_o,

  // ROM interface (master)
  output logic              rom_req_o,
  output logic [15:0]       rom_addr_o,
  input  logic [31:0]       rom_data_i,
  input  logic              rom_valid_i,

  // Add missing manager interface signals as unused inputs/outputs
  output logic              mgr_req_o,    // added as output, tied low internally
  output logic [15:0]       mgr_addr_o,   // dummy
  output logic              mgr_we_o,     // dummy
  output logic [31:0]       mgr_wdata_o,  // dummy
  input  logic              mgr_gnt_i,    // dummy input
  input  logic              mgr_rvalid_i, // dummy input
  input  logic [31:0]       mgr_rdata_i   // dummy input
);

  import obi_pkg::*;  // OBI constants
  import user_pkg::*;

  typedef enum logic [1:0] {
    IDLE    = 2'd0,
    FETCH   = 2'd1,
    COMPUTE = 2'd2,
    DONE    = 2'd3
  } state_e;

  state_e state_q, state_d;

  logic [31:0] center_pixel_q;
  logic [7:0] result_q;

  logic start_q, start_d;
  logic done_q;

  // 3x3 window address (centered at addr_q), hardcoded pattern
  logic [3:0] fetch_idx_q;
  logic [15:0] base_addr_q;
  logic rom_reading_q;
  logic [7:0] pixels_q [0:8];

  // Output registers for CPU read
  logic obi_read;
  logic obi_write;
  logic [31:0] obi_rdata;

  assign obi_read  = obi_req_i.req && !obi_req_i.we;
  assign obi_write = obi_req_i.req &&  obi_req_i.we;

  // OBI response
  assign obi_rsp_o.gnt   = obi_req_i.req; // always ready
  assign obi_rsp_o.rvalid= obi_read;
  assign obi_rsp_o.rdata = obi_rdata;

  // OBI register map offsets
  localparam int unsigned CENTER_REG_OFFSET = 0;
  localparam int unsigned STATUS_REG_OFFSET = 4;
  localparam int unsigned RESULT_REG_OFFSET = 8;

  // CPU writes center pixel address to start
  always_comb begin
    start_d = start_q;
    base_addr_q = center_pixel_q[15:0];
    if (obi_write && obi_req_i.a.addr[3:0] == CENTER_REG_OFFSET) begin
      start_d = 1'b1;
    end
  end

  // FSM control
  always_comb begin
    state_d = state_q;
    rom_req_o = 1'b0;
    rom_addr_o = 16'd0;
    done_q = 1'b0;

    case (state_q)
      IDLE: begin
        if (start_q) begin
          fetch_idx_q = 0;
          state_d = FETCH;
        end
      end

      FETCH: begin
        rom_req_o = 1'b1;
        rom_addr_o = base_addr_q - 17 + fetch_idx_q; // address offset for 3x3 grid
        if (rom_valid_i) begin
          pixels_q[fetch_idx_q] = rom_data_i[7:0]; // Only use lower byte
          fetch_idx_q = fetch_idx_q + 1;
          if (fetch_idx_q == 8)
            state_d = COMPUTE;
        end
      end

      COMPUTE: begin
        automatic int gx, gy, mag;
        gx = -pixels_q[0] + pixels_q[2]
           - 2*pixels_q[3] + 2*pixels_q[5]
           - pixels_q[6] + pixels_q[8];

        gy = -pixels_q[0] - 2*pixels_q[1] - pixels_q[2]
           + pixels_q[6] + 2*pixels_q[7] + pixels_q[8];

        mag = (gx < 0 ? -gx : gx) + (gy < 0 ? -gy : gy);
        result_q = (mag > 255) ? 8'hFF : mag[7:0];

        state_d = DONE;
      end

      DONE: begin
        done_q = 1'b1;
        start_d = 1'b0;
        state_d = IDLE;
      end
    endcase
  end

  // OBI read-back mux
  always_comb begin
    obi_rdata = 32'd0;
    case (obi_req_i.a.addr[3:0])
      STATUS_REG_OFFSET: obi_rdata = {31'd0, done_q};
      RESULT_REG_OFFSET: obi_rdata = {24'd0, result_q};
      CENTER_REG_OFFSET: obi_rdata = center_pixel_q;
      default: obi_rdata = 32'hDEADBEEF;
    endcase
  end

  // Registers
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= IDLE;
      start_q <= 1'b0;
      center_pixel_q <= 32'd0;
    end else begin
      state_q <= state_d;
      start_q <= start_d;
      if (obi_write && obi_req_i.a.addr[3:0] == CENTER_REG_OFFSET)
        center_pixel_q <= obi_req_i.wdata;
    end
  end

  // Tie off unused manager outputs
  assign mgr_req_o   = 1'b0;
  assign mgr_addr_o  = 16'd0;
  assign mgr_we_o    = 1'b0;
  assign mgr_wdata_o = 32'd0;

endmodule
