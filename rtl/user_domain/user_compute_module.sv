module user_compute_module (
  input  logic [31:0] rpixels_i,      // Input: 4 packed 8-bit pixels
  input  logic        is_valid_i,     // Input: valid signal from OBI streamer
  input  logic [7:0]  threshold_i,    // Input: threshold value

  output logic [31:0] wdata_o       // Output: 4 packed thresholded pixels
);

  // Unpack input pixels
  logic [7:0] pixel0, pixel1, pixel2, pixel3;
  assign pixel0 = rpixels_i[7:0];
  assign pixel1 = rpixels_i[15:8];
  assign pixel2 = rpixels_i[23:16];
  assign pixel3 = rpixels_i[31:24];

  // Thresholded output pixels
  logic [7:0] out0, out1, out2, out3;

  always_comb begin
    if (is_valid_i) begin
      out0 = (pixel0 > threshold_i) ? 8'hFF : 8'h00;
      out1 = (pixel1 > threshold_i) ? 8'hFF : 8'h00;
      out2 = (pixel2 > threshold_i) ? 8'hFF : 8'h00;
      out3 = (pixel3 > threshold_i) ? 8'hFF : 8'h00;
    end else begin
      out0 = 8'h00;
      out1 = 8'h00;
      out2 = 8'h00;
      out3 = 8'h00;
    end
  end

  // Pack result back into 32-bit word
  assign wdata_o = {out3, out2, out1, out0};

endmodule
