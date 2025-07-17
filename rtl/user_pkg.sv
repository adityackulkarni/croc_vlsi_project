// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Philippe Sauter <phsauter@iis.ee.ethz.ch>
// - Updated by Aditya, 2025

`include "register_interface/typedef.svh"
`include "obi/typedef.svh"

package user_pkg;

  ////////////////////////////////
  // User Manager Address maps //
  ///////////////////////////////
  
  // None

  localparam int unsigned NumUserDomainManagers = 1;

  localparam bit [31:0] UserMemAddrOffset = 32'h2000_0000;
  localparam bit [31:0] UserMemAddrRange  = 32'h0000_1000; // 64KB (adjust to match your memory)

  localparam croc_pkg::addr_map_rule_t [0:0] user_mgr_addr_map = '{
    '{
      start_addr: UserMemAddrOffset,
      end_addr:   UserMemAddrOffset + UserMemAddrRange - 1,
      idx:        0  // assuming only one manager port
    }
  };


  /////////////////////////////////////
  // User Subordinate Address maps ////
  /////////////////////////////////////

  localparam int unsigned NumUserDomainSubordinates = 1;

  localparam bit [31:0] UserRomAddrOffset   = croc_pkg::UserBaseAddr; // 32'h2000_0000;
  localparam bit [31:0] UserRomAddrRange    = 32'h0000_1000;           // 4KB per device

  localparam int unsigned NumDemuxSbrRules  = NumUserDomainSubordinates;
  localparam int unsigned NumDemuxSbr       = NumDemuxSbrRules + 1;

  // Enum for bus indices
  typedef enum int {
    UserAccel = 0,
    UserError = 1
  } user_demux_outputs_e;


  // Address rules given to address decoder
  localparam croc_pkg::addr_map_rule_t [NumDemuxSbrRules-1:0] user_addr_map = '{
    '{ // Rule 0: Sobel Accelerator
      start_addr: UserRomAddrOffset,
      end_addr:   UserRomAddrOffset + UserRomAddrRange - 1,
      idx:        SobelAccel
    }
  };

endpackage
