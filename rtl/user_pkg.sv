// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Philippe Sauter <phsauter@iis.ee.ethz.ch>

`include "register_interface/typedef.svh"
`include "obi/typedef.svh"

package user_pkg;

  ////////////////////////////////
  // User Manager Address maps //
  ///////////////////////////////
  
  // None


  /////////////////////////////////////
  // User Subordinate Address maps ////
  /////////////////////////////////////

  localparam int unsigned NumUserDomainSubordinates = 2;

  // Common subordinate address range size: 4 KB
  localparam bit [31:0] UserSubordinateRange = 32'h0000_1000;

  // Base addresses for subordinates (relative to croc_pkg::UserBaseAddr)
  localparam bit [31:0] UserEdgeDetectAddrOffset = croc_pkg::UserBaseAddr + 32'h0000_0000;
  localparam bit [31:0] UserEdgeDetectAddrRange  = UserSubordinateRange;

  localparam bit [31:0] UserRomAddrOffset        = croc_pkg::UserBaseAddr + 32'h0000_1000;
  localparam bit [31:0] UserRomAddrRange         = UserSubordinateRange;

  localparam int unsigned NumDemuxSbrRules  = NumUserDomainSubordinates; // Number of address rules
  localparam int unsigned NumDemuxSbr       = NumDemuxSbrRules + 1;      // Plus one error subordinate

  // Enum for subordinate indices + error subordinate
  typedef enum int {
    UserEdgeDetect = 0,
    UserRom        = 1,
    UserError      = 2
  } user_demux_outputs_e;

  // Address map rules for subordinate address decoder (error excluded)
  localparam croc_pkg::addr_map_rule_t [NumDemuxSbrRules-1:0] user_addr_map = '{
    '{ idx: UserEdgeDetect, start_addr: UserEdgeDetectAddrOffset, end_addr: UserEdgeDetectAddrOffset + UserEdgeDetectAddrRange },
    '{ idx: UserRom,        start_addr: UserRomAddrOffset,        end_addr: UserRomAddrOffset        + UserRomAddrRange }
  };

endpackage
