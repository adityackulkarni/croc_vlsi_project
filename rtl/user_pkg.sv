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

  // Change - 1: Change NumUserDomainSubordinates from 0 to 1 as we are adding tbd_accel in user domain 
  // localparam int unsigned NumUserDomainSubordinates = 0;
  localparam int unsigned NumUserDomainSubordinates = 1;
  // Changed this for tbd_accel


  // MMIO base and range
  localparam bit [31:0] UserRomAddrOffset   = croc_pkg::UserBaseAddr; // 32'h2000_0000;
  localparam bit [31:0] UserRomAddrRange    = 32'h0000_1000;          // every subordinate has at least 4KB


  // Derived constants for bus muxing
  localparam int unsigned NumDemuxSbrRules  = NumUserDomainSubordinates; // number of address rules in the decoder
  localparam int unsigned NumDemuxSbr       = NumDemuxSbrRules + 1; // additional OBI error, used for signal arrays

  // Enum for bus indices
  typedef enum int {
    // Change - 2: Add user tbd for tbd_accel 
    UserTbd   = 0,  // Your tbd_accel goes here
    // UserError = 0

    // Change - 3: Change user error as it becomes 2nd
    UserError = 1 // Change from 0 to 1 as 2 things and this is second one
  } user_demux_outputs_e;

  // Address rules given to address decoder
  // localparam croc_pkg::addr_map_rule_t [NumDemuxSbrRules-1:0] user_addr_map = '0;

  // Change - 4: Assign region for tbd_accel address
  // Address map rules: tell the address decoder how to route MMIO traffic
  localparam croc_pkg::addr_map_rule_t [NumDemuxSbrRules-1:0] user_addr_map = '{
    '{ idx:0, start_addr: 32'h2000_0000, end_addr: 32'h2000_0FFF }  // 4 KB region for tbd_accel
  };

endpackage
