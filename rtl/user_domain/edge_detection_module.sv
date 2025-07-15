module edge_detection_module #(
  parameter int THRESHOLD = 100
)(
  // Pixel inputs (signed 8-bit grayscale)
  input  logic signed [7:0] p00, p01, p02,  // top row
  input  logic signed [7:0] p10,      p12,  // middle row (excluding center)
  input  logic signed [7:0] p20, p21, p22,  // bottom row

  input  logic use_threshold,              // Enable thresholding
  output logic        edge,                // 1 if edge detected (optional)
  output logic signed [15:0] gx,           // horizontal gradient
  output logic signed [15:0] gy,           // vertical gradient
  output logic [15:0] magnitude            // |gx| + |gy| (approximate)
);

  // Sobel Gx:
  // [-1  0  +1]
  // [-2  0  +2]
  // [-1  0  +1]
  assign gx = -p00 + p02
            - (p10 <<< 1) + (p12 <<< 1)
            - p20 + p22;

  // Sobel Gy:
  // [-1 -2 -1]
  // [ 0  0  0]
  // [+1 +2 +1]
  assign gy = -p00 - (p01 <<< 1) - p02
            + p20 + (p21 <<< 1) + p22;

  // Magnitude approximation
  logic [15:0] abs_gx, abs_gy;
  assign abs_gx = gx[15] ? -gx : gx;
  assign abs_gy = gy[15] ? -gy : gy;
  assign magnitude = abs_gx + abs_gy;

  // Optional edge output
  assign edge = use_threshold && (magnitude > THRESHOLD);

endmodule
