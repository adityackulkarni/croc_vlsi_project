// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

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

  localparam int unsigned NumUserDomainSubordinates = 1; // Edge detection accelerator

  localparam bit [31:0] EdgeDetectAddrOffset = croc_pkg::UserBaseAddr; // 32'h2000_0000;
  localparam bit [31:0] EdgeDetectAddrRange  = 32'h0000_1000; // 4KB

  localparam int unsigned NumDemuxSbrRules  = NumUserDomainSubordinates;
  localparam int unsigned NumDemuxSbr       = NumDemuxSbrRules + 1; // additional OBI error

  // Enum for bus indices
  typedef enum int {
    UserEdgeDetect = 0,
    UserError = 1
  } user_demux_outputs_e;

  // Address rules given to address decoder
  localparam croc_pkg::addr_map_rule_t [NumDemuxSbrRules-1:0] user_addr_map = '{
    '{ idx: UserEdgeDetect,
       start_addr: EdgeDetectAddrOffset,
       end_addr: EdgeDetectAddrOffset + EdgeDetectAddrRange}
  };

endpackage