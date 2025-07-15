module sobel_accel_top (
  input  logic         clk,
  input  logic         rst_n,

  // MMIO interface from CVE2 core
  input  logic         mmio_req,
  input  logic [31:0]  mmio_addr,
  input  logic         mmio_we,
  input  logic [31:0]  mmio_wdata,
  output logic [31:0]  mmio_rdata,
  output logic         mmio_rvalid,

  // OBI interface to SRAM (as Manager)
  output logic         obi_req,
  input  logic         obi_gnt,
  output logic [31:0]  obi_addr,
  output logic         obi_we,
  output logic [3:0]   obi_be,
  output logic [31:0]  obi_wdata,
  output logic [3:0]   obi_aid,
  input  logic         obi_rvalid,
  input  logic [31:0]  obi_rdata,
  input  logic         obi_err,
  input  logic [3:0]   obi_rid
);

  // === Parameters ===
  localparam int IMG_WIDTH     = 28;
  localparam int IMG_HEIGHT    = 28;
  localparam logic [31:0] IMG_BASE_ADDR = 32'h1000_0000;
  localparam int THRESHOLD     = 100;

  // === MMIO Registers ===
  logic start_reg, done_reg;

  // === MMIO Access ===
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_reg <= 1'b0;
    end else if (mmio_req && mmio_we) begin
      if (mmio_addr == 32'h2000_0000)  // Write to 'start'
        start_reg <= mmio_wdata[0];
    end else if (done_reg) begin
      // Auto-clear start once done
      start_reg <= 1'b0;
    end
  end

  // === MMIO Readback ===
  always_comb begin
    mmio_rdata  = 32'b0;
    mmio_rvalid = 1'b0;
    if (mmio_req && !mmio_we) begin
      mmio_rvalid = 1'b1;
      case (mmio_addr)
        32'h2000_0004: mmio_rdata = {31'b0, done_reg};  // Done flag
        default:       mmio_rdata = 32'hDEADBEEF;
      endcase
    end
  end

  // === Internal Wires ===
  logic        read_req, write_req;
  logic [31:0] addr, write_data;
  logic [31:0] read_data;
  logic        read_valid, write_ready;

  logic        valid_pixels;
  logic signed [7:0] p00, p01, p02,
                     p10,      p12,
                     p20, p21, p22;

  logic [15:0] sobel_result;
  logic        edge_unused;
  logic signed [15:0] gx_unused, gy_unused;

  // === FSM Controller ===
  controller ctrl (
    .clk         (clk),
    .rst_n       (rst_n),
    .start       (start_reg),
    .done        (done_reg),

    .read_req    (read_req),
    .write_req   (write_req),
    .addr        (addr),
    .write_data  (write_data),
    .read_data   (read_data),
    .read_valid  (read_valid),
    .write_ready (write_ready),

    .valid_pixels(valid_pixels),
    .p00(p00), .p01(p01), .p02(p02),
    .p10(p10),           .p12(p12),
    .p20(p20), .p21(p21), .p22(p22),
    .result     (sobel_result)
  );

  // === OBI Master Interface ===
  obi_mimo obi (
    .clk         (clk),
    .rst_n       (rst_n),
    .read_req    (read_req),
    .write_req   (write_req),
    .addr        (addr),
    .wdata       (write_data),
    .read_done   (read_valid),
    .write_done  (write_ready),
    .rdata       (read_data),

    .obi_req     (obi_req),
    .obi_gnt     (obi_gnt),
    .obi_addr    (obi_addr),
    .obi_we      (obi_we),
    .obi_be      (obi_be),
    .obi_wdata   (obi_wdata),
    .obi_aid     (obi_aid),

    .obi_rvalid  (obi_rvalid),
    .obi_rdata   (obi_rdata),
    .obi_err     (obi_err),
    .obi_rid     (obi_rid)
  );

  // === Sobel Core ===
  edge_detection_module #(
    .THRESHOLD (THRESHOLD)
  ) sobel_core (
    .p00(p00), .p01(p01), .p02(p02),
    .p10(p10),           .p12(p12),
    .p20(p20), .p21(p21), .p22(p22),
    .use_threshold(1'b0),
    .edge      (edge_unused),
    .gx        (gx_unused),
    .gy        (gy_unused),
    .magnitude (sobel_result)
  );

endmodule
