// tbd_accel.sv
module tbd_accel #(
  parameter logic [31:0] BASE_ADDR = 32'h1000_0000  // SRAM base address for image
) (
  input  logic        clk,
  input  logic        rst_n,

  // OBI-like MMIO interface signals from MMIO wrapper
  input  logic        start,    // MMIO write to start register
  output logic        done,     // MMIO read from done register
  output logic        match,    // MMIO read from match register

  // Simple SRAM read-only interface
  output logic [31:0] sram_addr,
  output logic        sram_req,
  input  logic [7:0]  sram_rdata,
  input  logic        sram_rvalid
);

  typedef enum logic [1:0] {
    IDLE,
    READ_PIXELS,
    CALC,
    DONE
  } state_t;

  state_t state_q, state_d;

  logic [3:0] pixel_index_q, pixel_index_d;
  logic [7:0] pixels_q[0:8];  // 9 pixels in 3x3 patch

  logic [15:0] sobel_result;
  logic [15:0] result_q;

  logic sram_req_d, sram_req_q;
  logic [31:0] sram_addr_d, sram_addr_q;

  // Sobel horizontal kernel
  localparam int signed filter[0:8] = '{
    -1, 0, 1,
    -2, 0, 2,
    -1, 0, 1
  };

  // Next state logic
  always_comb begin
    state_d       = state_q;
    pixel_index_d = pixel_index_q;
    sram_req_d    = 1'b0;
    sram_addr_d   = sram_addr_q;

    case (state_q)
      IDLE: begin
        if (start) begin
          state_d       = READ_PIXELS;
          pixel_index_d = 0;
          sram_req_d    = 1'b1;
          sram_addr_d   = BASE_ADDR;
        end
      end

      READ_PIXELS: begin
        if (sram_rvalid) begin
          if (pixel_index_q < 8) begin
            pixel_index_d = pixel_index_q + 1;
            sram_req_d    = 1'b1;
            sram_addr_d   = BASE_ADDR + pixel_index_q + 1;
          end else if (pixel_index_q == 8) begin
            state_d = CALC;
        end
      end

      CALC: begin
        state_d = DONE;
      end

      DONE: begin
        // Stay here until reset or next trigger
        if (!start) begin
          state_d = IDLE;
        end
      end
    endcase
  end

  // FSM registers
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q       <= IDLE;
      pixel_index_q <= 0;
      sram_addr_q   <= '0;
      sram_req_q    <= 1'b0;
    end else begin
      state_q       <= state_d;
      pixel_index_q <= pixel_index_d;
      sram_addr_q   <= sram_addr_d;
      sram_req_q    <= sram_req_d;
    end
  end

  // Pixel latch
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < 9; i++) pixels_q[i] <= 0;
    end else if (state_q == READ_PIXELS && sram_rvalid) begin
      pixels_q[pixel_index_q] <= sram_rdata;
    end
  end

  // Sobel computation
  always_comb begin
    sobel_result = 0;
    for (int i = 0; i < 9; i++) begin
      sobel_result += $signed(filter[i]) * $signed(pixels_q[i]);
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result_q <= 0;
    end else if (state_q == CALC) begin
      result_q <= sobel_result;
    end
  end

  // MMIO outputs
  assign done  = (state_q == DONE);
  assign match = (result_q > 100);

  // SRAM interface
  assign sram_addr  = sram_addr_q;
  assign sram_req   = sram_req_q;

endmodule
