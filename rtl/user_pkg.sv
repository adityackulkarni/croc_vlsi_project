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

  // Number of subordinates (ROM + EdgeAccel)
  localparam int unsigned NumUserDomainSubordinates = 2;

  // Address ranges and offsets
  localparam bit [31:0] UserRomAddrOffset       = croc_pkg::UserBaseAddr;      // e.g., 32'h2000_0000
  localparam bit [31:0] UserRomAddrRange        = 32'h0000_1000;               // 4 KB for ROM

  localparam bit [31:0] UserEdgeAccelAddrOffset = croc_pkg::UserBaseAddr + 32'h0000_1000; // next 4 KB region
  localparam bit [31:0] UserEdgeAccelAddrRange  = 32'h0000_1000;               // 4 KB for Edge Accelerator

  // Number of address decoder rules = number of subordinates
  localparam int unsigned NumDemuxSbrRules = NumUserDomainSubordinates;

  // Number of subordinate ports = rules + 1 (for error)
  localparam int unsigned NumDemuxSbr = NumDemuxSbrRules + 1;

  // Enumerated indices for demux outputs (subordinate buses)
  typedef enum int {
    UserError     = 0, // default fallback subordinate
    UserRom       = 1,
    UserEdgeAccel = 2
  } user_demux_outputs_e;

  // Address map rules used by addr_decode module
  // UserError is default and thus not included here
  localparam croc_pkg::addr_map_rule_t [NumDemuxSbrRules-1:0] user_addr_map = '{
    '{ idx: UserRom,       start_addr: UserRomAddrOffset,       end_addr: UserRomAddrOffset + UserRomAddrRange - 1 },
    '{ idx: UserEdgeAccel, start_addr: UserEdgeAccelAddrOffset, end_addr: UserEdgeAccelAddrOffset + UserEdgeAccelAddrRange - 1 }
  };

endpackage