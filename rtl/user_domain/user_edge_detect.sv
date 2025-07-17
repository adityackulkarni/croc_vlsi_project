module user_edge_accel #(
  parameter ADDR_WIDTH = 16,
  parameter DATA_WIDTH = 32,
  parameter ID_WIDTH   = 4
)(
  input  wire                  clk_i,
  input  wire                  rst_ni,

  // OBI Slave Interface (from Croc core)
  input  wire                  sbr_obi_req_i,
  input  wire [ADDR_WIDTH-1:0] sbr_obi_addr_i,
  input  wire [DATA_WIDTH-1:0] sbr_obi_wdata_i,
  input  wire                  sbr_obi_we_i,
  input  wire [ID_WIDTH-1:0]   sbr_obi_id_i,

  output reg                   sbr_obi_gnt_o,
  output reg                   sbr_obi_rvalid_o,
  output reg [DATA_WIDTH-1:0]  sbr_obi_rdata_o,
  output reg [ID_WIDTH-1:0]    sbr_obi_rid_o,
  output reg                   sbr_obi_err_o,

  // OBI Master Interface (to SRAM)
  output reg                   mgr_obi_req_o,
  output reg [ADDR_WIDTH-1:0]  mgr_obi_addr_o,
  output reg [DATA_WIDTH-1:0]  mgr_obi_wdata_o,
  output reg                   mgr_obi_we_o,
  output reg [ID_WIDTH-1:0]    mgr_obi_id_o,

  input  wire                  mgr_obi_gnt_i,
  input  wire                  mgr_obi_rvalid_i,
  input  wire [DATA_WIDTH-1:0] mgr_obi_rdata_i,
  input  wire [ID_WIDTH-1:0]   mgr_obi_rid_i,
  input  wire                  mgr_obi_err_i
);

  typedef enum logic [1:0] {
    IDLE,
    READ_SRAM,
    PROCESS,
    WRITE_BACK
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [ADDR_WIDTH-1:0] addr_reg;
  reg [DATA_WIDTH-1:0] buffer_reg;
  reg [ID_WIDTH-1:0]   id_reg;

  // Sequential logic
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state <= IDLE;
      sbr_obi_gnt_o = 1'b0;
      sbr_obi_rvalid_o = 1'b0;
      sbr_obi_err_o = 1'b0;
    end else begin
      state <= next_state;

      // Reset default outputs each cycle
      sbr_obi_gnt_o = 1'b0;
      sbr_obi_rvalid_o = 1'b0;
      sbr_obi_err_o = 1'b0;
    end
  end

  // Combinational logic
  always_comb begin
    // Default outputs
    next_state = state;

    mgr_obi_req_o   = 1'b0;
    mgr_obi_addr_o  = addr_reg;
    mgr_obi_wdata_o = buffer_reg;
    mgr_obi_we_o    = 1'b0;
    mgr_obi_id_o    = id_reg;

    sbr_obi_rdata_o = buffer_reg;
    sbr_obi_rid_o   = id_reg;

    case (state)
      IDLE: begin
        if (sbr_obi_req_i) begin
          sbr_obi_gnt_o = 1'b1;
          addr_reg = sbr_obi_addr_i;
          id_reg = sbr_obi_id_i;

          if (sbr_obi_we_i) begin
            // Write request: forward directly to SRAM
            mgr_obi_req_o   = 1'b1;
            mgr_obi_we_o    = 1'b1;
            mgr_obi_addr_o  = sbr_obi_addr_i;
            mgr_obi_wdata_o = sbr_obi_wdata_i;
            mgr_obi_id_o    = sbr_obi_id_i;

            if (mgr_obi_gnt_i) begin
              sbr_obi_rvalid_o = 1'b1;
              next_state = IDLE;
            end else begin
              next_state = WRITE_BACK;
            end
          end else begin
            // Read request: issue read to SRAM
            mgr_obi_req_o  = 1'b1;
            mgr_obi_we_o   = 1'b0;
            mgr_obi_addr_o = sbr_obi_addr_i;
            mgr_obi_id_o   = sbr_obi_id_i;
            next_state = READ_SRAM;
          end
        end
      end

      READ_SRAM: begin
        if (mgr_obi_rvalid_i && mgr_obi_rid_i == id_reg) begin
          buffer_reg = mgr_obi_rdata_i;
          next_state = PROCESS;
        end
      end

      PROCESS: begin
        buffer_reg = buffer_reg >> 1;
        next_state = WRITE_BACK;
      end

      WRITE_BACK: begin
        mgr_obi_req_o   = 1'b1;
        mgr_obi_we_o    = 1'b1;
        mgr_obi_addr_o  = addr_reg;
        mgr_obi_wdata_o = buffer_reg;
        mgr_obi_id_o    = id_reg;

        if (mgr_obi_gnt_i) begin
          sbr_obi_rvalid_o = 1'b1;
          next_state = IDLE;
        end
      end
    endcase
  end

endmodule
