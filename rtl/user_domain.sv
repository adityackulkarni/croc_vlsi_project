`include "common_cells/registers.svh"

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

  input  logic [GpioCount-1:0] gpio_in_sync_i,
  output logic [NumExternalIrqs-1:0] interrupts_o
);

  assign interrupts_o = '0;
  assign user_mgr_obi_req_o = '0;

  // Subordinate buses
  sbr_obi_req_t [NumDemuxSbr-1:0] all_user_sbr_obi_req;
  sbr_obi_rsp_t [NumDemuxSbr-1:0] all_user_sbr_obi_rsp;

  // ROM Interface
  sbr_obi_req_t user_rom_obi_req;
  sbr_obi_rsp_t user_rom_obi_rsp;

  // Edge Accelerator Interface
  sbr_obi_req_t user_edge_obi_req;
  sbr_obi_rsp_t user_edge_obi_rsp;

  // Error Interface
  sbr_obi_req_t user_error_obi_req;
  sbr_obi_rsp_t user_error_obi_rsp;

  // Signal assignments
  assign user_rom_obi_req = all_user_sbr_obi_req[UserRom];
  assign user_edge_obi_req = all_user_sbr_obi_req[UserEdgeAccel];
  assign user_error_obi_req = all_user_sbr_obi_req[UserError];

  assign all_user_sbr_obi_rsp[UserRom] = user_rom_obi_rsp;
  assign all_user_sbr_obi_rsp[UserEdgeAccel] = user_edge_obi_rsp;
  assign all_user_sbr_obi_rsp[UserError] = user_error_obi_rsp;

  // Address decoder
  logic [cf_math_pkg::idx_width(NumDemuxSbr)-1:0] user_idx;

  addr_decode #(
    .NoIndices (NumDemuxSbr),
    .NoRules   (NumDemuxSbrRules),
    .addr_t    (logic[SbrObiCfg.DataWidth-1:0]),
    .rule_t    (addr_map_rule_t),
    .Napot     (1'b0)
  ) i_addr_decode_users (
    .addr_i           (user_sbr_obi_req_i.a.addr),
    .addr_map_i       (user_addr_map),
    .idx_o            (user_idx),
    .dec_valid_o      (),
    .dec_error_o      (),
    .en_default_idx_i (1'b1),
    .default_idx_i    (UserError)
  );

  // OBI Demux
  obi_demux #(
    .ObiCfg      (SbrObiCfg),
    .obi_req_t   (sbr_obi_req_t),
    .obi_rsp_t   (sbr_obi_rsp_t),
    .NumMgrPorts (NumDemuxSbr),
    .NumMaxTrans (2)
  ) i_user_demux (
    .clk_i,
    .rst_ni,
    .sbr_port_select_i (user_idx),
    .sbr_port_req_i    (user_sbr_obi_req_i),
    .sbr_port_rsp_o    (user_sbr_obi_rsp_o),
    .mgr_ports_req_o   (all_user_sbr_obi_req),
    .mgr_ports_rsp_i   (all_user_sbr_obi_rsp)
  );

  // User ROM Instance (modified version)
  user_rom #(
    .ObiCfg      (SbrObiCfg),
    .obi_req_t   (sbr_obi_req_t),
    .obi_rsp_t   (sbr_obi_rsp_t)
  ) i_user_rom (
    .clk_i,
    .rst_ni,
    .obi_req_i  (user_rom_obi_req),
    .obi_rsp_o  (user_rom_obi_rsp),
    .accel_req_i (edge_accel_rom_req),
    .accel_addr_i (edge_accel_rom_addr),
    .accel_data_o (edge_accel_rom_data),
    .accel_valid_o (edge_accel_rom_valid)
  );

  // Edge Detection Accelerator
  user_edge_detect i_user_edge_detect (
    .clk_i,
    .rst_ni,
    .rom_req_o (edge_accel_rom_req),
    .rom_addr_o (edge_accel_rom_addr),
    .rom_data_i (edge_accel_rom_data),
    .rom_valid_i (edge_accel_rom_valid),
    .start_i (gpio_in_sync_i[0]),  // Use GPIO 0 as start trigger
    .done_o (interrupts_o[0])      // Use interrupt 0 for completion
  );

  // Error Subordinate
  obi_err_sbr #(
    .ObiCfg      (SbrObiCfg),
    .obi_req_t   (sbr_obi_req_t),
    .obi_rsp_t   (sbr_obi_rsp_t),
    .NumMaxTrans (1),
    .RspData     (32'hBADCAB1E)
  ) i_user_err (
    .clk_i,
    .rst_ni,
    .testmode_i (testmode_i),
    .obi_req_i  (user_error_obi_req),
    .obi_rsp_o  (user_error_obi_rsp)
  );

endmodule