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
  
  input  sbr_obi_req_t user_sbr_obi_req_i,
  output sbr_obi_rsp_t user_sbr_obi_rsp_o,

  output mgr_obi_req_t user_mgr_obi_req_o,
  input  mgr_obi_rsp_t user_mgr_obi_rsp_i,

  input  logic [      GpioCount-1:0] gpio_in_sync_i,
  output logic [NumExternalIrqs-1:0] interrupts_o
);

  assign interrupts_o = '0;  

  ////////////////////////////
  // User Manager MUX     //
  ////////////////////////////

  mgr_obi_req_t user_edge_detect_mgr_req;
  mgr_obi_rsp_t user_edge_detect_mgr_rsp;

  assign user_mgr_obi_req_o = user_edge_detect_mgr_req;
  assign user_edge_detect_mgr_rsp = user_mgr_obi_rsp_i;

  ////////////////////////////
  // User Subordinate DEMUX //
  ////////////////////////////

  sbr_obi_req_t [NumDemuxSbr-1:0] all_user_sbr_obi_req;
  sbr_obi_rsp_t [NumDemuxSbr-1:0] all_user_sbr_obi_rsp;

  sbr_obi_req_t user_edge_detect_obi_req;
  sbr_obi_rsp_t user_edge_detect_obi_rsp;

  sbr_obi_req_t user_rom_obi_req;
  sbr_obi_rsp_t user_rom_obi_rsp;

  sbr_obi_req_t user_error_obi_req;
  sbr_obi_rsp_t user_error_obi_rsp;

  assign user_edge_detect_obi_req              = all_user_sbr_obi_req[UserEdgeDetect];
  assign all_user_sbr_obi_rsp[UserEdgeDetect]  = user_edge_detect_obi_rsp;

  assign user_rom_obi_req                      = all_user_sbr_obi_req[UserRom];
  assign all_user_sbr_obi_rsp[UserRom]         = user_rom_obi_rsp;

  assign user_error_obi_req                    = all_user_sbr_obi_req[UserError];
  assign all_user_sbr_obi_rsp[UserError]       = user_error_obi_rsp;

  logic [cf_math_pkg::idx_width(NumDemuxSbr)-1:0] user_idx;

  addr_decode #(
    .NoIndices ( NumDemuxSbr ),
    .NoRules   ( NumDemuxSbrRules ),
    .addr_t    ( logic[SbrObiCfg.DataWidth-1:0] ),
    .rule_t    ( addr_map_rule_t ),
    .Napot     ( 1'b0 ),
    .idx_t     ( user_demux_outputs_e )
  ) i_addr_decode_users (
    .addr_i           ( user_sbr_obi_req_i.a.addr ),
    .addr_map_i       ( user_addr_map             ),
    .idx_o            ( user_idx                  ),
    .dec_valid_o      (),
    .dec_error_o      (),
    .en_default_idx_i ( 1'b1 ),
    .default_idx_i    ( UserError )
  );

  obi_demux #(
    .ObiCfg      ( SbrObiCfg     ),
    .obi_req_t   ( sbr_obi_req_t ),
    .obi_rsp_t   ( sbr_obi_rsp_t ),
    .NumMgrPorts ( NumDemuxSbr   ),
    .NumMaxTrans ( 2             )
  ) i_user_demux (
    .clk_i,
    .rst_ni,

    .sbr_port_select_i ( user_idx             ),
    .sbr_port_req_i    ( user_sbr_obi_req_i   ),
    .sbr_port_rsp_o    ( user_sbr_obi_rsp_o   ),

    .mgr_ports_req_o   ( all_user_sbr_obi_req ),
    .mgr_ports_rsp_i   ( all_user_sbr_obi_rsp )
  );

  // --- ROM interface signals between user_edge_detect and user_rom
  logic              rom_req;
  logic [15:0]       rom_addr;
  logic [31:0]       rom_data;
  logic              rom_valid;

  // Convert rom_req/rom_addr to OBI request signals for user_rom
  // Build OBI read request to user_rom from rom_req and rom_addr
  sbr_obi_req_t rom_obi_req;
  sbr_obi_rsp_t rom_obi_rsp;

  assign rom_obi_req.req  = rom_req;
  assign rom_obi_req.we   = 1'b0;            // ROM read only
  assign rom_obi_req.a.addr = { {(SbrObiCfg.DataWidth-16){1'b0}}, rom_addr }; // pad upper bits to full addr width
  assign rom_obi_req.wdata = 32'd0;          // no write data on read
  assign rom_obi_req.wstrb = 4'b0000;        // no write strobes
  assign rom_obi_req.id    = 0;
  assign rom_obi_req.user  = 0;

  // Connect user_rom OBI slave interface to this request
  assign user_rom_obi_req = rom_obi_req;
  assign rom_obi_rsp = user_rom_obi_rsp;

  // Provide data and valid from user_rom OBI response back to user_edge_detect
  assign rom_data  = rom_obi_rsp.rdata;
  assign rom_valid = rom_obi_rsp.rvalid;

  // User Edge Detection Accelerator
  user_edge_detect #(
    .ObiCfg(SbrObiCfg),
    .obi_req_t(sbr_obi_req_t),
    .obi_rsp_t(sbr_obi_rsp_t)
  ) i_user_edge_detect (
    .clk_i     ( clk_i ),
    .rst_ni    ( rst_ni ),
    .obi_req_i ( user_edge_detect_obi_req ),
    .obi_rsp_o ( user_edge_detect_obi_rsp ),
    // Manager interface
    .mgr_req_o ( user_edge_detect_mgr_req ),
    .mgr_rsp_i ( user_edge_detect_mgr_rsp ),
    // ROM interface
    .rom_req_o ( rom_req ),
    .rom_addr_o( rom_addr ),
    .rom_data_i( rom_data ),
    .rom_valid_i( rom_valid )
  );

  // User ROM (accessed over manager port)
  user_rom #(
    .ObiCfg      ( SbrObiCfg     ),
    .obi_req_t   ( sbr_obi_req_t ),
    .obi_rsp_t   ( sbr_obi_rsp_t )
  ) i_user_rom (
    .clk_i,
    .rst_ni,
    .obi_req_i  ( user_rom_obi_req ),
    .obi_rsp_o  ( user_rom_obi_rsp )
  );

  // Error responder for unmapped accesses
  obi_err_sbr #(
    .ObiCfg      ( SbrObiCfg     ),
    .obi_req_t   ( sbr_obi_req_t ),
    .obi_rsp_t   ( sbr_obi_rsp_t ),
    .NumMaxTrans ( 1             ),
    .RspData     ( 32'hBADCAB1E  )
  ) i_user_err (
    .clk_i,
    .rst_ni,
    .testmode_i ( testmode_i ),
    .obi_req_i  ( user_error_obi_req ),
    .obi_rsp_o  ( user_error_obi_rsp )
  );

endmodule
