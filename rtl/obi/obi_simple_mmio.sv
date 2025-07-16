// obi_simple_mmio.sv
// Custom MMIO Wrapper for Edge Detection Accelerator using OBI interface

module obi_simple_mmio #(
  parameter int unsigned BaseAddr = 32'h0000_0000
) (
  input  logic        clk_i,
  input  logic        rst_ni,

  // OBI Bus Interface
  OBI_BUS.Subordinate mmio_bus,

  // Control and Status
  output logic        start_o,
  output logic        clear_o,
  input  logic        done_i,
  output logic [31:0] img_base_addr_o,
  output logic [15:0] img_width_o,
  output logic [15:0] img_height_o
);

  typedef enum logic [2:0] {
    REG_START         = 3'h0,
    REG_CLEAR         = 3'h1,
    REG_DONE          = 3'h2,
    REG_IMG_BASE_ADDR = 3'h3,
    REG_IMG_WIDTH     = 3'h4,
    REG_IMG_HEIGHT    = 3'h5
  } reg_addr_e;

  // Internal registers
  logic [31:0] img_base_addr_q, img_base_addr_d;
  logic [15:0] img_width_q, img_width_d;
  logic [15:0] img_height_q, img_height_d;
  logic        start_q, start_d;
  logic        clear_q, clear_d;

  // Assign outputs
  assign img_base_addr_o = img_base_addr_q;
  assign img_width_o     = img_width_q;
  assign img_height_o    = img_height_q;
  assign start_o         = start_q;
  assign clear_o         = clear_q;

  // OBI signal aliases
  logic        acc_sel;
  logic [2:0]  reg_addr;

  assign acc_sel  = mmio_bus.req && (mmio_bus.addr[31:16] == BaseAddr[31:16]);
  assign reg_addr = mmio_bus.addr[4+:3];

  // Grant logic
  assign mmio_bus.gnt = acc_sel;

  // Write logic
  always_comb begin
    start_d         = 1'b0;
    clear_d         = 1'b0;
    img_base_addr_d = img_base_addr_q;
    img_width_d     = img_width_q;
    img_height_d    = img_height_q;

    if (acc_sel && mmio_bus.we) begin
      unique case (reg_addr)
        REG_START:         start_d         = 1'b1;
        REG_CLEAR:         clear_d         = 1'b1;
        REG_IMG_BASE_ADDR: img_base_addr_d = mmio_bus.wdata;
        REG_IMG_WIDTH:     img_width_d     = mmio_bus.wdata[15:0];
        REG_IMG_HEIGHT:    img_height_d    = mmio_bus.wdata[15:0];
        default: ;
      endcase
    end
  end

  // Read logic
  always_comb begin
    mmio_bus.rvalid = acc_sel && !mmio_bus.we;
    mmio_bus.rdata  = 32'h0000_0000;
    mmio_bus.err    = 1'b0;

    if (acc_sel && !mmio_bus.we) begin
      unique case (reg_addr)
        REG_DONE:          mmio_bus.rdata = {31'b0, done_i};
        REG_IMG_BASE_ADDR: mmio_bus.rdata = img_base_addr_q;
        REG_IMG_WIDTH:     mmio_bus.rdata = {16'b0, img_width_q};
        REG_IMG_HEIGHT:    mmio_bus.rdata = {16'b0, img_height_q};
        default:           mmio_bus.rdata = 32'hDEAD_BEEF;
      endcase
    end
  end

  // Output handshake handling
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      start_q         <= 1'b0;
      clear_q         <= 1'b0;
      img_base_addr_q <= '0;
      img_width_q     <= '0;
      img_height_q    <= '0;
    end else begin
      start_q         <= start_d;
      clear_q         <= clear_d;
      img_base_addr_q <= img_base_addr_d;
      img_width_q     <= img_width_d;
      img_height_q    <= img_height_d;
    end
  end

endmodule
