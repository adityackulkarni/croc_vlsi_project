// gives us the `FF(...) macro making it easy to have properly defined flip-flops
`include "common_cells/registers.svh"

module user_obi_streamer #(
  /// The OBI configuration for all ports.
  parameter obi_pkg::obi_cfg_t           ObiCfg      = obi_pkg::ObiDefaultConfig,
  /// The request struct.
  parameter type                         obi_req_t   = logic,
  /// The response struct.
  parameter type                         obi_rsp_t   = logic
) (
  /// Clock and Reset
  input  logic clk_i,
  input  logic rst_ni,
  
  /// Stream Control
  input logic is_req_i,                         // control signal -> HIGH = move to ADDR_PHASE
  input logic is_write_i,                       // control signal -> LOW => mode = READ, HIGH => mode = WRITE

  /// Address and Data to READ/WRITE
  input logic [ObiCfg.AddrWidth-1:0] rw_addr_i, // if (mode == READ) then read from rw_addr_i, else write to rw_addr_i
  input logic [ObiCfg.DataWidth-1:0] wdata_i,   // if (mode == WRITE) then write wdata_i to SRAM0 via OBI, else this is zero

  /// Output to the Compute Module
  output logic [ObiCfg.DataWidth-1:0] rpixels,  // 32 bits of 4 pixels passed to compute module
  output logic is_valid,                        // valid signal to make sure compute module performs computation on valid data

  /// OBI response interface
  input  obi_rsp_t obi_rsp_i,
  /// OBI request interface
  output obi_req_t obi_req_o
);

/// DECLARE SIGNALS FOR OBI RESPONSE ///
logic rvalid_d, rvalid_q;
logic gnt_d, gnt_q;
logic [ObiCfg.DataWidth-1:0] rdata_d, rdata_q;
logic err_d, err_q;
logic [ObiCfg.IdWidth-1:0] id_d, id_q;

`FF(rvalid_q, rvalid_d, '0);
`FF(gnt_q,    gnt_d,    '0);
`FF(rdata_q,  rdata_d,  '0);
`FF(err_q,    err_d,    '0);
`FF(id_q,     id_d,     '0);

assign rvalid_d = obi_rsp_i.rvalid;
assign gnt_d    = obi_rsp_i.gnt;
assign rdata_d  = obi_rsp_i.r.rdata;
assign err_d    = obi_rsp_i.r.err;
assign id_d     = obi_rsp_i.r.rid;

/// FSM State Declaration ///
typedef enum logic [1:0] {
  IDLE, ADDR_PHASE, RESP_PHASE
} state_t;

state_t state_q, state_d;
`FF(state_q, state_d, IDLE);

/// Latched OBI Request Info ///
logic req_we_d, req_we_q;
logic [ObiCfg.AddrWidth-1:0] req_addr_d, req_addr_q;
logic [ObiCfg.DataWidth-1:0] req_data_d, req_data_q;

`FF(req_we_q,   req_we_d,   '0);
`FF(req_addr_q, req_addr_d, '0);
`FF(req_data_q, req_data_d, '0);

/// Latched Control Inputs ///
logic is_req_d, is_req_q;
logic is_write_d, is_write_q;

`FF(is_req_q,    is_req_d,    '0);
`FF(is_write_q,  is_write_d,  '0);

assign is_req_d    = is_req_i;
assign is_write_d  = is_write_i;

/// FSM Logic ///
always_comb begin
  state_d = state_q;

  // Default: keep latched request values
  req_we_d    = req_we_q;
  req_addr_d  = req_addr_q;
  req_data_d  = req_data_q;

  case (state_q)

    IDLE: begin
      if (is_req_q) begin
        req_we_d    = is_write_q;
        req_addr_d  = rw_addr_i;
        req_data_d  = is_write_q ? wdata_i : '0;
        state_d     = ADDR_PHASE;
      end
    end

    ADDR_PHASE: begin
      if (gnt_q) begin
        state_d = RESP_PHASE;
      end
    end

    RESP_PHASE: begin
      if (rvalid_q) begin
        state_d = IDLE;
      end
    end

    default: state_d = IDLE;

  endcase
end

/// OBI REQUEST ASSIGNMENTS ///
assign obi_req_o.req     = (state_q == ADDR_PHASE);

assign obi_req_o.a.addr  = req_addr_q;
assign obi_req_o.a.we    = req_we_q;
assign obi_req_o.a.be    = '1; // Full word access
assign obi_req_o.a.wdata = req_data_q;
assign obi_req_o.a.aid   = '0; // Unused

/// COMPUTE MODULE OUTPUTS ///
assign rpixels  = rdata_q;
assign is_valid = (state_q == RESP_PHASE) && rvalid_q;



endmodule
