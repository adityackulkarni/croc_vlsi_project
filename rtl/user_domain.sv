// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Philippe Sauter <phsauter@iis.ee.ethz.ch>
// - Updated by Aditya, 2025

module user_domain import user_pkg::*; import croc_pkg::*; #(
  parameter int unsigned GpioCount = 16,
  parameter int unsigned DATA_WIDTH = 32,
  parameter int unsigned ADDR_WIDTH = 32
) (
  input  logic      clk_i,
  input  logic      ref_clk_i,
  input  logic      rst_ni,
  input  logic      testmode_i,

  input  sbr_obi_req_t user_sbr_obi_req_i,
  output sbr_obi_rsp_t user_sbr_obi_rsp_o,

  output logic        user_mgr_req_o,
  output logic        user_mgr_we_o,
  output logic [31:0] user_mgr_addr_o,
  output logic [31:0] user_mgr_wdata_o,
  output logic [3:0]  user_mgr_be_o,
  input  logic        user_mgr_gnt_i,
  input  logic        user_mgr_rvalid_i,
  input  logic [31:0] user_mgr_rdata_i,

  input  logic [      GpioCount-1:0] gpio_in_sync_i,
  output logic [NumExternalIrqs-1:0] interrupts_o
);

  ////////////////////////////
  // Internal Manager Signals
  ////////////////////////////

  logic                  accel_mgr_req;
  logic                  accel_mgr_we;
  logic [31:0]           accel_mgr_addr;
  logic [31:0]           accel_mgr_wdata;
  logic [3:0]            accel_mgr_be;
  logic                  accel_mgr_gnt;
  logic                  accel_mgr_rvalid;
  logic [31:0]           accel_mgr_rdata;

  logic [cf_math_pkg::idx_width(NumUserDomainManagers)-1:0] user_mgr_idx;

  addr_decode #(
    .NoIndices        ( NumUserDomainManagers              ),
    .NoRules          ( NumUserDomainManagers              ),
    .addr_t           ( logic[31:0]                        ),
    .rule_t           ( addr_map_rule_t                    ),
    .Napot            ( 1'b0                               )
  ) i_user_mgr_addr_decode (
    .addr_i           ( accel_mgr_addr                     ),
    .addr_map_i       ( user_mgr_addr_map                  ),
    .idx_o            ( user_mgr_idx                       ),
    .dec_valid_o      ( /* unused */                       ),
    .dec_error_o      ( /* unused */                       ),
    .en_default_idx_i ( 1'b1                               ),
    .default_idx_i    ( '0                                 )
  );

  obi_mux #(
    .ObiCfg           ( MgrObiCfg                          ),
    .obi_req_t        ( logic                              ),
    .obi_rsp_t        ( logic                              ),
    .NumSubPorts      ( NumUserDomainManagers              ),
    .NumMaxTrans      ( 2                                  )
  ) i_user_mgr_obi_mux (
    .clk_i,
    .rst_ni,

    .sub_ports_req_i     ( '{ accel_mgr_req    }           ),
    .sub_ports_we_i      ( '{ accel_mgr_we     }           ),
    .sub_ports_addr_i    ( '{ accel_mgr_addr   }           ),
    .sub_ports_wdata_i   ( '{ accel_mgr_wdata  }           ),
    .sub_ports_be_i      ( '{ accel_mgr_be     }           ),
    .sub_ports_gnt_o     ( '{ accel_mgr_gnt    }           ),
    .sub_ports_rvalid_o  ( '{ accel_mgr_rvalid }           ),
    .sub_ports_rdata_o   ( '{ accel_mgr_rdata  }           ),

    .sbr_port_select_i   ( user_mgr_idx                   ),
    .sbr_port_req_o      ( user_mgr_req_o                 ),
    .sbr_port_we_o       ( user_mgr_we_o                  ),
    .sbr_port_addr_o     ( user_mgr_addr_o                ),
    .sbr_port_wdata_o    ( user_mgr_wdata_o               ),
    .sbr_port_be_o       ( user_mgr_be_o                  ),
    .sbr_port_gnt_i      ( user_mgr_gnt_i                 ),
    .sbr_port_rvalid_i   ( user_mgr_rvalid_i              ),
    .sbr_port_rdata_i    ( user_mgr_rdata_i               )
  );

  ////////////////////////////
  // User Subordinate DEMUX //
  ////////////////////////////

  sbr_obi_req_t [NumDemuxSbr-1:0] all_user_sbr_obi_req;
  sbr_obi_rsp_t [NumDemuxSbr-1:0] all_user_sbr_obi_rsp;

  // Error Subordinate Bus
  sbr_obi_req_t user_error_obi_req;
  sbr_obi_rsp_t user_error_obi_rsp;

  assign user_error_obi_req              = all_user_sbr_obi_req[UserError];
  assign all_user_sbr_obi_rsp[UserError] = user_error_obi_rsp;

  // Accelerator Subordinate Bus
  sbr_obi_req_t user_accel_obi_req;
  sbr_obi_rsp_t user_accel_obi_rsp;

  assign user_accel_obi_req              = all_user_sbr_obi_req[SobelAccel];
  assign all_user_sbr_obi_rsp[SobelAccel] = user_accel_obi_rsp;

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
    .dec_valid_o      (/* unused */               ),
    .dec_error_o      (/* unused */               ),
    .en_default_idx_i ( 1'b1                      ),
    .default_idx_i    ( '0                        )
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
    .testmode_i ( testmode_i         ),
    .obi_req_i  ( user_error_obi_req ),
    .obi_rsp_o  ( user_error_obi_rsp )
  );

  // Edge Detection Accelerator
  logic accel_interrupt;

  tbd_accel #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
  ) i_tbd_accel (
    .clk_i             (clk_i),
    .rst_ni            (rst_ni),

    // Manager interface
    .obi_mgr_req_o     (accel_mgr_req),
    .obi_mgr_we_o      (accel_mgr_we),
    .obi_mgr_addr_o    (accel_mgr_addr),
    .obi_mgr_wdata_o   (accel_mgr_wdata),
    .obi_mgr_be_o      (accel_mgr_be),
    .obi_mgr_gnt_i     (accel_mgr_gnt),
    .obi_mgr_rvalid_i  (accel_mgr_rvalid),
    .obi_mgr_rdata_i   (accel_mgr_rdata),

    // Subordinate interface
    .obi_sbr_req_i     (user_accel_obi_req.req),
    .obi_sbr_we_i      (user_accel_obi_req.we),
    .obi_sbr_addr_i    (user_accel_obi_req.addr),
    .obi_sbr_wdata_i   (user_accel_obi_req.wdata),
    .obi_sbr_be_i      (user_accel_obi_req.be),
    .obi_sbr_gnt_o     (user_accel_obi_rsp.gnt),
    .obi_sbr_rvalid_o  (user_accel_obi_rsp.rvalid),
    .obi_sbr_rdata_o   (user_accel_obi_rsp.rdata),

    .interrupt_o       (accel_interrupt)
  );

  // Interrupt mapping
  assign interrupts_o = { {(NumExternalIrqs-1){1'b0}}, accel_interrupt };

endmodule
