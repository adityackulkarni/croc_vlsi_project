module user_edge_detect #(
  parameter type obi_req_t  = logic,
  parameter type obi_rsp_t  = logic
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
  input  logic              rom_valid_i
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

  logic [31:0] center_pixel_q, center_pixel_d;
  logic start_q, start_d;
  logic done_q, done_d;

  logic [3:0] fetch_idx_q, fetch_idx_d;
  logic [15:0] base_addr_q, base_addr_d;

  logic [7:0] pixels_q [0:8];
  logic [7:0] pixels_d [0:8];

  logic [7:0] result_q, result_d;

  logic obi_read;
  logic obi_write;
  logic [31:0] obi_rdata;

  assign obi_read  = obi_req_i.req && !obi_req_i.we;
  assign obi_write = obi_req_i.req &&  obi_req_i.we;

  // OBI response
  assign obi_rsp_o.gnt    = obi_req_i.req;    // always ready
  assign obi_rsp_o.rvalid = obi_read && (obi_req_i.a.addr[3:0] != 4'hF); // valid on read except invalid addr
  assign obi_rsp_o.rdata  = obi_rdata;

  // Register offsets
  localparam int unsigned CENTER_REG_OFFSET = 0;
  localparam int unsigned STATUS_REG_OFFSET = 4;
  localparam int unsigned RESULT_REG_OFFSET = 8;

  // Start signal logic
  always_comb begin
    start_d = start_q;
    base_addr_d = base_addr_q;

    if (obi_write && (obi_req_i.a.addr[3:0] == CENTER_REG_OFFSET)) begin
      start_d = 1'b1;
      base_addr_d = obi_req_i.wdata[15:0]; // CPU writes center pixel address
    end else if (done_q) begin
      start_d = 1'b0;
    end
  end

  // FSM combinational
  always_comb begin
    state_d = state_q;
    fetch_idx_d = fetch_idx_q;
    done_d = done_q;
    result_d = result_q;

    rom_req_o = 1'b0;
    rom_addr_o = 16'd0;

    // Default pixel values unchanged
    for (int i = 0; i < 9; i++) begin
      pixels_d[i] = pixels_q[i];
    end

    case (state_q)
      IDLE: begin
        done_d = 1'b0;
        if (start_q) begin
          fetch_idx_d = 0;
          state_d = FETCH;
        end
      end

      FETCH: begin
        rom_req_o = 1'b1;
        // Address offset for 3x3 window around center pixel
        // Assuming image width = 16 pixels
        // 3x3 offsets (row,col):
        // 0: -1,-1; 1: -1,0; 2: -1,+1
        // 3:  0,-1; 4:  0,0; 5:  0,+1
        // 6: +1,-1; 7: +1,0; 8: +1,+1

        logic signed [4:0] row_offset [0:8];
        logic signed [4:0] col_offset [0:8];

        initial begin
          row_offset[0] = -1; row_offset[1] = -1; row_offset[2] = -1;
          row_offset[3] =  0; row_offset[4] =  0; row_offset[5] =  0;
          row_offset[6] =  1; row_offset[7] =  1; row_offset[8] =  1;

          col_offset[0] = -1; col_offset[1] =  0; col_offset[2] =  1;
          col_offset[3] = -1; col_offset[4] =  0; col_offset[5] =  1;
          col_offset[6] = -1; col_offset[7] =  0; col_offset[8] =  1;
        end


        rom_addr_o = base_addr_q + row_offset[fetch_idx_q]*16 + col_offset[fetch_idx_q];

        if (rom_valid_i) begin
          pixels_d[fetch_idx_q] = rom_data_i[7:0]; // Use only lower byte
          if (fetch_idx_q == 8)
            state_d = COMPUTE;
          else
            fetch_idx_d = fetch_idx_q + 1;
        end
      end

      COMPUTE: begin
        int gx, gy, mag;

        gx = -pixels_q[0] + pixels_q[2]
             - 2*pixels_q[3] + 2*pixels_q[5]
             - pixels_q[6] + pixels_q[8];

        gy = -pixels_q[0] - 2*pixels_q[1] - pixels_q[2]
             + pixels_q[6] + 2*pixels_q[7] + pixels_q[8];

        mag = (gx < 0 ? -gx : gx) + (gy < 0 ? -gy : gy);
        result_d = (mag > 255) ? 8'hFF : mag[7:0];

        state_d = DONE;
      end

      DONE: begin
        done_d = 1'b1;
        state_d = IDLE;
      end

      default: state_d = IDLE;
    endcase
  end

  // OBI read mux
  always_comb begin
    case (obi_req_i.a.addr[3:0])
      CENTER_REG_OFFSET: obi_rdata = {16'd0, base_addr_q};
      STATUS_REG_OFFSET: obi_rdata = {31'd0, done_q};
      RESULT_REG_OFFSET: obi_rdata = {24'd0, result_q};
      default:           obi_rdata = 32'hDEADBEEF;
    endcase
  end

  // Sequential update
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= IDLE;
      start_q <= 1'b0;
      done_q <= 1'b0;
      fetch_idx_q <= 0;
      base_addr_q <= 0;
      result_q <= 0;
      for (int i = 0; i < 9; i++)
        pixels_q[i] <= 0;
    end else begin
      state_q <= state_d;
      start_q <= start_d;
      done_q <= done_d;
      fetch_idx_q <= fetch_idx_d;
      base_addr_q <= base_addr_d;
      result_q <= result_d;
      for (int i = 0; i < 9; i++)
        pixels_q[i] <= pixels_d[i];
    end
  end

endmodule
