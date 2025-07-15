module edge_detection_module #(
  parameter int THRESHOLD = 100
)(
  // Pixel inputs (signed 8-bit grayscale)
  input  logic signed [7:0] p00, p02,    // top-left, top-right
  input  logic signed [7:0] p10, p12,    // mid-left, mid-right
  input  logic signed [7:0] p20, p22,    // bottom-left, bottom-right

  // Outputs
  output logic        edge,              // 1 if edge detected (magnitude > threshold)
  output logic signed [15:0] gx,         // horizontal gradient
  output logic signed [15:0] gy,         // vertical gradient
  output logic [15:0] magnitude          // |gx| + |gy| (approximate)
);

  // Gx = (p00 * -1 + p02 * +1) + (p10 * -2 + p12 * +2) + (p20 * -1 + p22 * +1)
  assign gx = -p00 + p02
            - (p10 <<< 1) + (p12 <<< 1)
            - p20 + p22;

  // Gy = (p00 * -1 + p20 * +1) + (p02 * -1 + p22 * +1) + (p10 * -2 + p12 * +2)
  assign gy = -p00 + p20
            - p02 + p22
            - (p10 <<< 1) + (p12 <<< 1);

  // Approximate magnitude = |gx| + |gy|
  logic [15:0] abs_gx, abs_gy;
  assign abs_gx = gx[15] ? -gx : gx;
  assign abs_gy = gy[15] ? -gy : gy;
  assign magnitude = abs_gx + abs_gy;

  // Compare to threshold
  assign edge = (magnitude > THRESHOLD);

endmodule
