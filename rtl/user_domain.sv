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

  assign interrupts_o = '0;  

  assign user_mgr_obi_req_o = '0;

  // Demux output to subordinates
  sbr_obi_req_t [NumDemuxSbr-1:0] all_user_sbr_obi_req;
  sbr_obi_rsp_t [NumDemuxSbr-1:0] all_user_sbr_obi_rsp;

  sbr_obi_req_t user_error_obi_req;
  sbr_obi_rsp_t user_error_obi_rsp;

  assign user_error_obi_req              = all_user_sbr_obi_req[UserError];
  assign all_user_sbr_obi_rsp[UserError] = user_error_obi_rsp;

  // Flattened OBI wires for tbd_accel
  logic        tbd_req;
  logic [31:0] tbd_addr;
  logic        tbd_we;
  logic [3:0]  tbd_be;
  logic [31:0] tbd_wdata;
  logic        tbd_rready;
  logic        tbd_gnt;
  logic        tbd_rvalid;
  logic [31:0] tbd_rdata;
  logic        tbd_err;

  assign tbd_req     = all_user_sbr_obi_req[UserTbd].req;
  assign tbd_addr    = all_user_sbr_obi_req[UserTbd].a.addr;
  assign tbd_we      = all_user_sbr_obi_req[UserTbd].a.we;
  assign tbd_be      = all_user_sbr_obi_req[UserTbd].a.be;
  assign tbd_wdata   = all_user_sbr_obi_req[UserTbd].a.wdata;
  assign tbd_rready  = all_user_sbr_obi_req[UserTbd].r.ready;

  assign all_user_sbr_obi_rsp[UserTbd].gnt        = tbd_gnt;
  assign all_user_sbr_obi_rsp[UserTbd].r.valid    = tbd_rvalid;
  assign all_user_sbr_obi_rsp[UserTbd].r.rdata    = tbd_rdata;
  assign all_user_sbr_obi_rsp[UserTbd].r.err      = tbd_err;

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
    .clk_i,
    .rst_ni,

    .sbr_port_select_i ( user_idx             ),
    .sbr_port_req_i    ( user_sbr_obi_req_i   ),
    .sbr_port_rsp_o    ( user_sbr_obi_rsp_o   ),

    .mgr_ports_req_o   ( all_user_sbr_obi_req ),
    .mgr_ports_rsp_i   ( all_user_sbr_obi_rsp )
  );

  // Error Subordinate
  obi_err_sbr #(
    .ObiCfg      ( SbrObiCfg     ),
    .obi_req_t   ( sbr_obi_req_t ),
    .obi_rsp_t   ( sbr_obi_rsp_t ),
    .NumMaxTrans ( 1             ),
    .RspData     ( 32'hBADCAB1E  )
  ) i_user_err (
    .clk_i,
    .rst_ni,
    .testmode_i ( testmode_i      ),
    .obi_req_i  ( user_error_obi_req ),
    .obi_rsp_o  ( user_error_obi_rsp )
  );

  // Accelerator control and status registers
  logic start_reg;
  logic done_reg;
  logic match_reg;

  // MMIO interface for tbd_accel
  obi_simple_mmio #(
    .ObiCfg     ( SbrObiCfg ),
    .DataWidth  ( 32        )
  ) i_tbd_accel_mmio (
    .clk_i     ( clk_i ),
    .rst_ni    ( rst_ni ),

    .req_i     ( tbd_req     ),
    .addr_i    ( tbd_addr    ),
    .we_i      ( tbd_we      ),
    .be_i      ( tbd_be      ),
    .wdata_i   ( tbd_wdata   ),
    .rready_i  ( tbd_rready  ),

    .gnt_o     ( tbd_gnt     ),
    .rvalid_o  ( tbd_rvalid  ),
    .rdata_o   ( tbd_rdata   ),
    .err_o     ( tbd_err     ),

    .start_o   ( start_reg ),
    .done_i    ( done_reg  ),
    .match_i   ( match_reg )
  );

  // Accelerator instantiation
  tbd_accel #(
    .BASE_ADDR(32'h2000_0000)
  ) i_user_tbd_accel (
    .clk        ( clk_i    ),
    .rst_n      ( rst_ni   ),

    .sram_addr   ( /* connect as needed */ ),
    .sram_req    ( /* connect as needed */ ),
    .sram_rdata  ( /* connect as needed */ ),
    .sram_rvalid ( /* connect as needed */ ),

    .start       ( start_reg ),
    .done        ( done_reg  ),
    .match       ( match_reg )
  );

endmodule
