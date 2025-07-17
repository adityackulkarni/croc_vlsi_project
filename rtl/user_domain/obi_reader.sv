// gives us the `FF(...) macro making it easy to have properly defined flip-flops
`include "common_cells/registers.svh"

// This module is supposed to issue 8 read transactions via OBI to SRAM0. 
// Will require internal FSM.

// TODO: Ask how are the pixels stored in memory
// If it's 8 bits, 8 bits 8 bits, then we need 2 OBI read requests per one Sobel kernel (8 pixels)
// If it's 8 bits 24 zeros 8 bits 24 zeros then we need 8 OBI read requests per one Sobel kernel
// Actually, I think we need 8 transactions anyway because we are not reading consecutive 8 bits in memory

module obi_reader #(
  /// The OBI configuration for all ports.
  parameter obi_pkg::obi_cfg_t           ObiCfg      = obi_pkg::ObiDefaultConfig,
  /// The request struct.
  parameter type                         obi_req_t   = logic,
  /// The response struct.
  parameter type                         obi_rsp_t   = logic
) (
  /// Clock
  input  logic clk_i,
  /// Active-low reset
  input  logic rst_ni,

  /// OBI request interface
  input  obi_req_t obi_req_i,
  /// OBI response interface
  output obi_rsp_t obi_rsp_o
);

// Define some registers to hold the requests fields
logic req_d, req_q;
logic we_d, we_q;
logic [ObiCfg.AddrWidth-1:0] addr_d, addr_q;
logic [ObiCfg.IdWidth-1:0] id_d, id_q;
logic [ObiCfg.DataWidth-1:0] wdata_d, wdata_q;

// Signals used to create the response
logic [ObiCfg.DataWidth-1:0] rsp_data; // Data field of the obi response
logic rsp_err; // Error field of the obi response

// Internal signals/registers
logic [15:0] set_bits_accumulator_d, set_bits_accumulator_q; // Holding the accumulated bitcount
logic [15:0] wdata_cnt; // Olding the bitcount of the request wdata

// Note to avoid writing trivial always_ff statements we can use this macro defined in registers.svh 
`FF(req_q, req_d, '0);
`FF(id_q , id_d , '0);
`FF(we_q , we_d , '0);
`FF(wdata_q , wdata_d , '0);
`FF(addr_q , addr_d , '0);
`FF(set_bits_accumulator_q, set_bits_accumulator_d, '0);

assign req_d = obi_req_i.req;
assign id_d = obi_req_i.a.aid;
assign we_d = obi_req_i.a.we;
assign addr_d = obi_req_i.a.addr;
assign wdata_d = obi_req_i.a.wdata;

// TODO: write a main always_comb block -> something like this
// After the RESP_PHASE we have access to the data we wanted
typedef enum logic [1:0] {
    IDLE, ADDR_PHASE, RESP_PHASE
} state_t;
 state_t state_q, state_d;

always_comb begin
state_d = state_q;
    case (state_q)
        IDLE: // if manager asserts req then the address phase over A channel starts
        if (obi_req_i.req) state_d = ADDR_PHASE;

        ADDR_PHASE:
        if (obi_gnt) next_state = WAIT_RESP;

        RESP_PHASE:
        if (obi_rvalid) next_state = IDLE;
    endcase
end

// Wire the response
// A channel
assign obi_rsp_o.gnt = obi_req_i.req;
// R channel:
assign obi_rsp_o.rvalid = req_q;
assign obi_rsp_o.r.rdata = rsp_data;
assign obi_rsp_o.r.rid = id_q;
assign obi_rsp_o.r.err = rsp_err;
assign obi_rsp_o.r.r_optional = '0;

endmodule
