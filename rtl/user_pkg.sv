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
  localparam int unsigned NumUserDomainManagers = 0;


  /////////////////////////////////////
  // User Subordinate Address maps ////
  /////////////////////////////////////

  localparam int unsigned NumUserDomainSubordinates = 1; // changed from 0 to 1

  // Use same base address croc_pkg::UserBaseAddr, and size 4KB for the new subordinate
  localparam bit [31:0] UserEdgeAccelAddrOffset = croc_pkg::UserBaseAddr; // 32'h2000_0000
  localparam bit [31:0] UserEdgeAccelAddrRange  = 32'h0000_1000;          // 4KB

  localparam int unsigned NumDemuxSbrRules  = NumUserDomainSubordinates; // now 1
  localparam int unsigned NumDemuxSbr       = NumDemuxSbrRules + 1;      // +1 for error

  // Enum for bus indices
  typedef enum int {
    UserError = 0,
    UserEdgeAccel = 1
  } user_demux_outputs_e;

  // Address rules given to address decoder
  localparam croc_pkg::addr_map_rule_t [NumDemuxSbrRules-1:0] user_addr_map = '{
    '{ idx: UserEdgeAccel, start_addr: UserEdgeAccelAddrOffset, end_addr: UserEdgeAccelAddrOffset + UserEdgeAccelAddrRange - 1 }
  };

endpackage