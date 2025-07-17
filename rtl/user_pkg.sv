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
  
  // We need to have this in order to connect to croc domain as managers
  localparam int unsigned NumCrocDomainSubordinates = 1; // NOTE: should be one because I only want to connect to SRAM0
  
  // We need to create address map so that EDM module knows where the SRAM is
  localparam bit [31:0] CrocSramAddrOffset  =  croc_pkg::SramBaseAddr;  // 32'h1000_0000;
  localparam bit [31:0] CrocSramAddrRange   =  croc_pkg::SramAddrRange; // TODO: ask if this is correct
  
  localparam int unsigned NumDemuxMgrRules  = NumCrocDomainSubordinates; // number of address rules in the decoder
  localparam int unsigned NumDemuxMgr       = NumDemuxMgrRules + 1; // additional OBI error, used for signal arrays

  // Enum for bus indices
  typedef enum int {
    CrocError = 0,
    CrocSRAM0 = 1
  } croc_demux_outputs_e;

  // Address rules given to address decoder
  // CrocError does not appear as it will be used as default rule TODO: ask if this is correct
  // Here we assume 1 possible connection UserDomain -> CrocDomain
  localparam croc_pkg::addr_map_rule_t [NumDemuxMgrRules-1:0] croc_addr_map = '{
    '{ idx:CrocSRAM0, start_addr: CrocSramAddrOffset, end_addr: CrocSramAddrOffset + CrocSramAddrRange}
  };


  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
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
