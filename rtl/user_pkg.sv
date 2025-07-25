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

  // TODO 2: Declare a unique index for the UserROM memory domain and modify this file accordingly

  localparam int unsigned NumUserDomainSubordinates = 2;

  localparam bit [31:0] UserRomAddrOffset   = croc_pkg::UserBaseAddr; // 32'h2000_0000;
  localparam bit [31:0] UserRomAddrRange    = 32'h0000_1000;          // every subordinate has at least 4KB
  localparam bit [31:0] UserEdgeDetectAddrOffset = 32'h2000_1000;
  localparam bit [31:0] UserEdgeDetectAddrRange = 32'h0000_1000;


  localparam int unsigned NumDemuxSbrRules  = NumUserDomainSubordinates; // number of address rules in the decoder
  localparam int unsigned NumDemuxSbr       = NumDemuxSbrRules + 1; // additional OBI error, used for signal arrays

  // Enum for bus indices
  typedef enum int {
    UserError = 0,
    UserRom = 1,
    UserEdgeDetect = 2
  } user_demux_outputs_e;

  // Address rules given to address decoder
  // UserError does not appear as it will be used as default rule
  localparam croc_pkg::addr_map_rule_t [NumDemuxSbrRules-1:0] user_addr_map = '{
    '{ idx:UserEdgeDetect, start_addr: UserEdgeDetectAddrOffset, end_addr: UserEdgeDetectAddrOffset + UserEdgeDetectAddrRange},
    '{ idx:UserRom, start_addr: UserRomAddrOffset, end_addr: UserRomAddrOffset + UserRomAddrRange}
  };

endpackage