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

  // Base addresses and ranges for subordinates
  localparam bit [31:0] UserEdgeDetectAddrOffset = croc_pkg::UserBaseAddr + 32'h0000_0000;  // Example base address
  localparam bit [31:0] UserEdgeDetectAddrRange  = 32'h0000_1000;  // 4 KB range

  localparam bit [31:0] UserRomAddrOffset        = croc_pkg::UserBaseAddr + 32'h0000_1000;  // ROM after EdgeDetect
  localparam bit [31:0] UserRomAddrRange         = 32'h0000_1000;  // 4 KB range

  localparam int unsigned NumDemuxSbrRules  = NumUserDomainSubordinates; // number of address rules in the decoder
  localparam int unsigned NumDemuxSbr       = NumDemuxSbrRules + 1; // additional OBI error, used for signal arrays

  // Enum for bus indices for subordinates + error
  typedef enum int {
    UserEdgeDetect = 0,
    UserRom        = 1,
    UserError      = 2
  } user_demux_outputs_e;

  // Address rules given to the address decoder for subordinates (error default excluded)
  localparam croc_pkg::addr_map_rule_t [NumDemuxSbrRules-1:0] user_addr_map = '{
    '{ idx: UserEdgeDetect, start_addr: UserEdgeDetectAddrOffset, end_addr: UserEdgeDetectAddrOffset + UserEdgeDetectAddrRange },
    '{ idx: UserRom,        start_addr: UserRomAddrOffset,        end_addr: UserRomAddrOffset        + UserRomAddrRange }
  };

endpackage