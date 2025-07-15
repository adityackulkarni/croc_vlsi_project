// Built to detect edges in a grayscale image using a 3x3 Sobel filter, typically used for edge detection in image processing.

// Steps:

// 1. Waits for start

// 2. Reads 9 consecutive pixels from SRAM starting at address 128

// 3. Applies a 3x3 Sobel horizontal filter by multiplying each pixel by the kernel and summing results

// 4. Compares accumulated sum with threshold (100)

// 5. Sets match to 1 if threshold exceeded, otherwise 0

// 6. Raises done signal to indicate processing complete

// 7. Waits for next start/reset cycle




module tbd_accel #(
  // Parameter to specify base address of MMIO (not used internally)
  parameter int BASE_ADDR = 32'h2000_0000  // 1 KB MMIO base address can see it in user_pkg.sv
)(
  input  logic        clk,       // Clock input
  input  logic        rst_n,     // Active-low synchronous reset

  // Memory interface to SRAM (image stored in Bank 0)
  output logic [9:0]  sram_addr,   // Address to read from SRAM (10-bit = 1024 entries max)
  output logic        sram_req,    // Request signal for SRAM read
  input  logic [31:0] sram_rdata,  // Data read from SRAM (32-bit, but we use only LSB)
  input  logic        sram_rvalid, // Signal that read data is valid

  // MMIO control signals
  input  logic start,   // MMIO: Start signal to begin computation
  output logic done,    // MMIO: Done signal to indicate processing finished
  output logic match    // MMIO: Match signal indicating result > threshold
);

  // FSM State encoding (2-bit enumeration)
  typedef enum logic [1:0] {
    IDLE,         // Wait for start
    READ_PIXELS,  // Read 9 pixels from SRAM
    COMPUTE,      // Apply filter and compare result
    DONE          // Raise done and wait for reset
  } state_t;

  state_t state, next_state; // FSM current and next state

  // 3x3 Sobel filter kernel (horizontal edge detection)
  // Values are hardcoded as signed 8-bit values
  logic signed [7:0] filter[0:8] = '{
     -1,  0,  1,
     -2,  0,  2,
     -1,  0,  1
  };

  // Accumulator for convolution result (signed 16-bit for enough range)
  logic signed [15:0] acc;

  // Index for reading pixels (0 to 8 = 9 reads)
  logic [3:0] read_idx;

  // Temporary register to store pixel byte (signed)
  logic signed [7:0] pixel_byte;

  // Address used to fetch pixel from SRAM (centered read)
  logic [9:0] pixel_addr;

  // Assign pixel address and request signal for SRAM interface
  assign sram_addr = pixel_addr;
  assign sram_req  = (state == READ_PIXELS);

  // FSM: Sequential state update
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= IDLE;       // Reset to IDLE
    else
      state <= next_state; // Go to computed next state
  end

  // FSM: Combinational next state logic
  always_comb begin
    next_state = state; // Default to staying in same state
    case (state)
      IDLE:        next_state = (start ? READ_PIXELS : IDLE);    // Wait for start
      READ_PIXELS: next_state = (read_idx == 9 ? COMPUTE : READ_PIXELS); // Read 9 pixels
      COMPUTE:     next_state = DONE;                            // Compute next
      DONE:        next_state = IDLE;                            // Return to idle
    endcase
  end

  // Main sequential logic: state-dependent behavior
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all internal states
      acc         <= 0;
      read_idx    <= 0;
      done        <= 0;
      match       <= 0;
      pixel_addr  <= 10'd128; // Center pixel address (adjust as needed)
    end else begin
      case (state)
        IDLE: begin
          // Clear all values on entering IDLE
          acc         <= 0;
          read_idx    <= 0;
          done        <= 0;
          match       <= 0;
          pixel_addr  <= 10'd128;
        end

        READ_PIXELS: begin
          // Issue read address (offset for each pixel around center)
          pixel_addr <= 10'd128 + read_idx;

          // Wait for read valid from SRAM
          if (sram_rvalid) begin
            // Extract only 8-bit LSB from SRAM read
            pixel_byte <= sram_rdata[7:0];

            // Multiply pixel by corresponding filter weight and accumulate
            acc <= acc + (filter[read_idx] * $signed(sram_rdata[7:0]));

            // Advance to next pixel
            read_idx <= read_idx + 1;
          end
        end

        COMPUTE: begin
          // Once all pixels read, compute match
          done  <= 1;              // Signal processing done
          match <= (acc > 100);    // Threshold comparison
        end

        DONE: begin
          // Wait here until FSM moves to IDLE again
          // (output signals stay latched)
        end
      endcase
    end
  end

endmodule
