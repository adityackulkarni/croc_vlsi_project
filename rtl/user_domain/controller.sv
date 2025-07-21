module controller (
  input  logic        clk,
  input  logic        rst_n,

  // Start + Done interface
  input  logic        start,
  output logic        done,

  // Control interface to obi_mimo
  output logic        read_req,
  output logic        write_req,
  output logic [31:0] addr,
  output logic [31:0] write_data,
  input  logic [31:0] read_data,
  input  logic        read_valid,
  input  logic        write_ready,

  // Outputs to edge detection core
  output logic        valid_pixels,
  output logic signed [7:0] p00, p01, p02,
                            p10,      p12,
                            p20, p21, p22,

  input  logic [15:0] result
);

  typedef enum logic [2:0] {
    IDLE, LOAD_PIXELS, WAIT_READS, COMPUTE, WRITE_RESULT, DONE
  } state_t;

  state_t state, next_state;

  localparam int IMG_WIDTH  = 28;
  localparam int IMG_HEIGHT = 28;
  localparam int IMG_SIZE   = IMG_WIDTH * IMG_HEIGHT;
  localparam logic [31:0] BASE_ADDR = 32'h1000_0000;

  logic [7:0] img[0:IMG_SIZE-1];  // Optional: simulate image buffer (not synthesized)
  logic [15:0] output_img[0:IMG_SIZE-1];

  logic [15:0] pixel_index;       // current pixel position
  logic [31:0] base_addr;

  logic [3:0] read_count;
  logic [31:0] pixel_buffer[0:8];

  // State machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else        state <= next_state;
  end

  always_comb begin
    next_state = state;
    case (state)
      IDLE:         if (start)           next_state = LOAD_PIXELS;
      LOAD_PIXELS:                        next_state = WAIT_READS;
      WAIT_READS:    if (read_valid)     next_state = COMPUTE;
      COMPUTE:                            next_state = WRITE_RESULT;
      WRITE_RESULT:  if (write_ready)    next_state = DONE;
      DONE:                               next_state = IDLE;
    endcase
  end

  // Address generation logic (example: fixed center pixel)
  logic [7:0] x, y;
  assign x = 8'd1; // TODO: update for real scanning
  assign y = 8'd1;

  // Read pixel values
  assign base_addr = BASE_ADDR + ((y - 1) * IMG_WIDTH + (x - 1)) * 4;

  assign addr = base_addr;
  assign read_req = (state == LOAD_PIXELS);
  assign write_req = (state == WRITE_RESULT);

  assign write_data = {16'b0, result};

  // Mock input (assuming read_valid fires immediately)
  always_ff @(posedge clk) begin
    if (read_valid) begin
      // Dummy fixed pattern for testing
      p00 <= $signed(read_data[7:0]);
      p01 <= $signed(read_data[7:0]);
      p02 <= $signed(read_data[7:0]);
      p10 <= $signed(read_data[7:0]);
      p12 <= $signed(read_data[7:0]);
      p20 <= $signed(read_data[7:0]);
      p21 <= $signed(read_data[7:0]);
      p22 <= $signed(read_data[7:0]);
    end
  end

  assign valid_pixels = (state == COMPUTE);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      done <= 1'b0;
    else if (state == DONE)
      done <= 1'b1;
    else
      done <= 1'b0;
  end

endmodule
