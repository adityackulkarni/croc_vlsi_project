// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Philippe Sauter <phsauter@iis.ee.ethz.ch>

`include "register_interface/typedef.svh"
`include "obi/typedef.svh"
// NOTE: This file should be done now.

package user_pkg;

  ////////////////////////////////
  // User Manager Address maps //
  ///////////////////////////////
  
  // None

  /////////////////////////////////////
  // User Subordinate Address maps ////
  /////////////////////////////////////

  localparam int unsigned NumUserDomainSubordinates = 1; // This needs to be 1 since we plan only one peripheral
  
  // The two lines below are commented out since we are not using User ROM
  // localparam bit [31:0] UserRomAddrOffset   = croc_pkg::UserBaseAddr; // 32'h2000_0000;
  // localparam bit [31:0] UserRomAddrRange    = 32'h0000_1000;          // every subordinate has at least 4KB

  // We need to create address map for our Edge Detection Module
  // We start at the base address of User Domain and allocate 4KB for EDM
  localparam bit [31:0] UserEDMAddrOffset   = croc_pkg::UserBaseAddr; // 32'h2000_0000;
  localparam bit [31:0] UserEDMAddrRange    = 32'h0000_1000;          // every subordinate has at least 4KB
  
  localparam int unsigned NumDemuxSbrRules  = NumUserDomainSubordinates; // number of address rules in the decoder
  localparam int unsigned NumDemuxSbr       = NumDemuxSbrRules + 1; // additional OBI error, used for signal arrays

  // Enum for bus indices
  typedef enum int {
    UserError = 0,
    UserEDM = 1
  } user_demux_outputs_e;

  // Address rules given to address decoder
  // UserError does not appear as it will be used as default rule
  // This was changed for EDM module. Should not require further changes, assuming one peripheral
  localparam croc_pkg::addr_map_rule_t [NumDemuxSbrRules-1:0] user_addr_map = '{
    '{ idx:UserEDM, start_addr: UserEDMAddrOffset, end_addr: UserEDMAddrOffset + UserEDMAddrRange}
  };

endpackage
