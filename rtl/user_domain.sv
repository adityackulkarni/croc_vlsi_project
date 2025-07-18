// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Philippe Sauter <phsauter@iis.ee.ethz.ch>

module user_domain import user_pkg::*; import croc_pkg::*; #(
  parameter int unsigned GpioCount = 16
) (
  input  logic      clk_i,
  input  logic      ref_clk_i,
  input  logic      rst_ni,
  input  logic      testmode_i,
  
  input  sbr_obi_req_t user_sbr_obi_req_i, // User Sbr (rsp_o), Croc Mgr (req_i)
  output sbr_obi_rsp_t user_sbr_obi_rsp_o,

  output mgr_obi_req_t user_mgr_obi_req_o, // User Mgr (req_o), Croc Sbr (rsp_i)
  input  mgr_obi_rsp_t user_mgr_obi_rsp_i,

  input  logic [      GpioCount-1:0] gpio_in_sync_i, // synchronized GPIO inputs
  output logic [NumExternalIrqs-1:0] interrupts_o // interrupts to core
);

  // Declare subordinate index for user_edge_accel
  localparam int unsigned kUserEdgeAccel = 1;

  assign interrupts_o = '0;  

  //////////////////////
  // User Manager MUX //
  /////////////////////

  // Internal signals to connect user_edge_accel master interface to user_domain master interface
  mgr_obi_req_t edge_accel_mgr_obi_req;
  mgr_obi_rsp_t edge_accel_mgr_obi_rsp;

  // Forward the internal master request to the user_mgr interface
  assign user_mgr_obi_req_o = edge_accel_mgr_obi_req;
  assign edge_accel_mgr_obi_rsp = user_mgr_obi_rsp_i;


  ////////////////////////////
  // User Subordinate DEMUX //
  ////////////////////////////

  // ----------------------------------------------------------------------------------------------
  // User Subordinate Buses
  // ----------------------------------------------------------------------------------------------
  
  // collection of signals from the demultiplexer
  sbr_obi_req_t [NumDemuxSbr-1:0] all_user_sbr_obi_req;
  sbr_obi_rsp_t [NumDemuxSbr-1:0] all_user_sbr_obi_rsp;

  // Error Subordinate Bus
  sbr_obi_req_t user_error_obi_req;
  sbr_obi_rsp_t user_error_obi_rsp;

  // Fanout into more readable signals
  assign user_error_obi_req              = all_user_sbr_obi_req[UserError];
  assign all_user_sbr_obi_rsp[UserError] = user_error_obi_rsp;


  //-----------------------------------------------------------------------------------------------
  // Demultiplex to User Subordinates according to address map
  //-----------------------------------------------------------------------------------------------

  logic [cf_math_pkg::idx_width(NumDemuxSbr)-1:0] user_idx;

  addr_decode #(
    .NoIndices ( NumDemuxSbr                    ),
    .NoRules   ( NumDemuxSbrRules               ),
    .addr_t    ( logic[SbrObiCfg.DataWidth-1:0] ),
    .rule_t    ( addr_map_rule_t                ),
    .Napot     ( 1'b0                           )
  ) i_addr_decode_periphs (
    .addr_i           ( user_sbr_obi_req_i.a.addr ),
    .addr_map_i       ( user_addr_map             ),
    .idx_o            ( user_idx                  ),
    .dec_valid_o      (),
    .dec_error_o      (),
    .en_default_idx_i ( 1'b1 ),
    .default_idx_i    ( '0   )
  );

  obi_demux #(
    .ObiCfg      ( SbrObiCfg     ),
    .obi_req_t   ( sbr_obi_req_t ),
    .obi_rsp_t   ( sbr_obi_rsp_t ),
    .NumMgrPorts ( NumDemuxSbr   ),
    .NumMaxTrans ( 2             )
  ) i_obi_demux (
    .clk_i      ( clk_i             ),
    .rst_ni     ( rst_ni            ),

    .sbr_port_select_i ( user_idx             ),
    .sbr_port_req_i    ( user_sbr_obi_req_i   ),
    .sbr_port_rsp_o    ( user_sbr_obi_rsp_o   ),

    .mgr_ports_req_o   ( all_user_sbr_obi_req ),
    .mgr_ports_rsp_i   ( all_user_sbr_obi_rsp )
  );


  //-------------------------------------------------------------------------------------------------
  // User Subordinates
  //-------------------------------------------------------------------------------------------------

  // Error Subordinate
  obi_err_sbr #(
    .ObiCfg      ( SbrObiCfg     ),
    .obi_req_t   ( sbr_obi_req_t ),
    .obi_rsp_t   ( sbr_obi_rsp_t ),
    .NumMaxTrans ( 1             ),
    .RspData     ( 32'hBADCAB1E  )
  ) i_user_err (
    .clk_i      ( clk_i           ),
    .rst_ni     ( rst_ni          ),
    .testmode_i ( testmode_i      ),
    .obi_req_i  ( user_error_obi_req ),
    .obi_rsp_o  ( user_error_obi_rsp )
  );

  // User edge accelerator subordinate instantiation
  user_edge_accel #(
    .ADDR_WIDTH(SbrObiCfg.AddrWidth),
    .DATA_WIDTH(SbrObiCfg.DataWidth),
    .ID_WIDTH(SbrObiCfg.IdWidth)
  ) i_user_edge_accel (
    .clk_i(clk_i),
    .rst_ni(rst_ni),

    // Slave interface from user_domain subordinate demux
    .sbr_obi_req_i(all_user_sbr_obi_req[kUserEdgeAccel].req),
    .sbr_obi_addr_i(all_user_sbr_obi_req[kUserEdgeAccel].a.addr),
    .sbr_obi_wdata_i(all_user_sbr_obi_req[kUserEdgeAccel].a.wdata),
    .sbr_obi_we_i(all_user_sbr_obi_req[kUserEdgeAccel].a.we),
    .sbr_obi_id_i(all_user_sbr_obi_req[kUserEdgeAccel].a.aid),

    .sbr_obi_gnt_o(all_user_sbr_obi_rsp[kUserEdgeAccel].gnt),
    .sbr_obi_rvalid_o(all_user_sbr_obi_rsp[kUserEdgeAccel].rvalid),
    .sbr_obi_rdata_o(all_user_sbr_obi_rsp[kUserEdgeAccel].r.rdata),
    .sbr_obi_rid_o(all_user_sbr_obi_rsp[kUserEdgeAccel].r.rid),
    .sbr_obi_err_o(all_user_sbr_obi_rsp[kUserEdgeAccel].r.err),

    // Master interface to SRAM via internal signals
    .mgr_obi_req_o(edge_accel_mgr_obi_req),
    .mgr_obi_addr_o(edge_accel_mgr_obi_req.a.addr),
    .mgr_obi_wdata_o(edge_accel_mgr_obi_req.a.wdata),
    .mgr_obi_we_o(edge_accel_mgr_obi_req.a.we),
    .mgr_obi_id_o(edge_accel_mgr_obi_req.a.aid),

    .mgr_obi_gnt_i(edge_accel_mgr_obi_rsp.gnt),
    .mgr_obi_rvalid_i(edge_accel_mgr_obi_rsp.rvalid),
    .mgr_obi_rdata_i(edge_accel_mgr_obi_rsp.r.rdata),
    .mgr_obi_rid_i(edge_accel_mgr_obi_rsp.r.rid),
    .mgr_obi_err_i(edge_accel_mgr_obi_rsp.r.err)
  );

endmodule
