// TOP MODULE
// NOTE: Since this is a MMIO peripheral for the CPU, it can only be accessed via OBI.
// Therefore, I think only inputs and outputs to the top module are clock, reset, obi_req and obi_rsp.

// gives us the `FF(...) macro making it easy to have properly defined flip-flops
`include "common_cells/registers.svh"

module sobel_accel_top #(
  /// The OBI configuration for all ports.
  parameter obi_pkg::obi_cfg_t           ObiCfg      = obi_pkg::ObiDefaultConfig,
  /// The request struct.
  parameter type                         obi_req_t   = logic,
  /// The response struct.
  parameter type                         obi_rsp_t   = logic,
)(
    /// Clock
  input  logic clk_i,
  /// Active-low reset
  input  logic rst_ni,

  /// OBI request interface FROM CPU
  input  obi_req_t obi_sbr_req_i,
  /// OBI request interface FROM SRAM
  input  obi_req_t obi_mgr_rsp_i,
  /// OBI response interface TO SRAM
  output obi_req_t obi_mgr_req_o,
  /// OBI response interface TO CPU
  output obi_rsp_t obi_sbr_rsp_o
);

// We define registers used to hold the request fields
logic req_d, req_q;
logic we_d, we_q;
logic [ObiCfg.AddrWidth-1:0] addr_d, addr_q;
logic [ObiCfg.IdWidth-1:0] id_d, id_q;
logic [ObiCfg.DataWidth-1:0] wdata_d, wdata_q;

 // Signals used to create the response
logic [ObiCfg.DataWidth-1:0] rsp_data; // Data field of the obi response UNCLEAR IF NEEDED
logic rsp_err; // Error field of the obi response                        UNCLEAR IF NEEDED


// Internal signals/registers
logic [15:0] edge_magnitude_d, edge_magnitude_q; // Edge magnitude that we will compute and write to memory


// We create registers for all the signals we defined using a macro
`FF(req_q, req_d, '0);
`FF(id_q , id_d , '0);
`FF(we_q , we_d , '0);
`FF(wdata_q , wdata_d , '0);
`FF(addr_q , addr_d , '0);
`FF(edge_magnitude_q, edge_magnitude_d, '0);

// We assign signals present in obi_req_i to our internal signals
assign req_d = obi_req_i.req;
assign id_d = obi_req_i.a.aid;
assign we_d = obi_req_i.a.we;
assign addr_d = obi_req_i.a.addr;
assign wdata_d = obi_req_i.a.wdata;

// Create states of the top level FSM
typedef enum logic [2:0] {  
  IDLE,
  READ,
  COMPUTE,
  WRITE,
  DONE
} state_t;

// Declare the variables for current and next state
state_t state_q, state_d; 

// Create a top level FSM
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    state_q <= IDLE;
    end
  else begin 
    state_q <= state_d;
    end 
  end 

always_comb begin
  state_d = state_q;
  case (state_q) // case on current state
    IDLE: begin
    end 
    READ: begin
    end 
    COMPUTE: begin
    end 
    WRITE: begin 
    end
    DONE: begin 
    end 
    default: begin 
    end 
  endcase 
end
// TODO 1 - Instantiate OBI streamer submodule
obi_streamer #() i_obi_streamer();
// TODO 2 - Instantiate EDM submodule

// Below we have the final part. Computation is finished and we can signal to CPU that edge detection is done.
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
