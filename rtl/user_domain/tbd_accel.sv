// Copyright 2024 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

module tbd_accel import croc_pkg::*; #(
  parameter int unsigned DataWidth = 32,
  parameter int unsigned AddrWidth = 32
) (
  input  logic                     clk_i,
  input  logic                     rst_ni,
  
  // OBI Manager Interface (to access memory)
  output sbr_obi_req_t             obi_mgr_req_o,
  input  sbr_obi_rsp_t             obi_mgr_rsp_i,
  
  // OBI Subordinate Interface (for control registers)
  input  mgr_obi_req_t             obi_sbr_req_i,
  output mgr_obi_rsp_t             obi_sbr_rsp_o,
  
  // Interrupt
  output logic                     interrupt_o
);


  // Control registers
  typedef struct packed {
    logic [AddrWidth-1:0] src_addr;
    logic [AddrWidth-1:0] dst_addr;
    logic [15:0]          width;
    logic [15:0]          height;
    logic                 start;
    logic                 done;
    logic                 enable;
  } ctrl_reg_t;
  
  ctrl_reg_t ctrl_reg_q, ctrl_reg_d;
  
  // State machine
  typedef enum logic [2:0] {
    IDLE,
    READ_ROW_1,
    READ_ROW_2,
    READ_ROW_3,
    PROCESS,
    WRITE_RESULT
  } state_e;
  
  state_e state_q, state_d;
  
  // Image buffer
  logic [7:0] window[3][3];
  logic [7:0] result_pixel;
  
  // Address counters
  logic [AddrWidth-1:0] read_addr_q, read_addr_d;
  logic [AddrWidth-1:0] write_addr_q, write_addr_d;
  logic [15:0]          x_cnt_q, x_cnt_d;
  logic [15:0]          y_cnt_q, y_cnt_d;
  
  // Sobel computation
  always_comb begin
    int gx, gy;
    logic [7:0] temp;
    
    // Sobel X kernel
    gx = (window[0][2] + 2*window[1][2] + window[2][2]) - 
         (window[0][0] + 2*window[1][0] + window[2][0]);
         
    // Sobel Y kernel
    gy = (window[2][0] + 2*window[2][1] + window[2][2]) - 
         (window[0][0] + 2*window[0][1] + window[0][2]);
         
    // Gradient magnitude (approximation)
    temp = (((gx < 0) ? -gx : gx) + ((gy < 0) ? -gy : gy)) >> 1;
    result_pixel = (temp > 8'h80) ? 8'hFF : 8'h00; // Threshold
  end
  
  // Control register interface
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      ctrl_reg_q <= '0;
      state_q <= IDLE;
      read_addr_q <= '0;
      write_addr_q <= '0;
      x_cnt_q <= '0;
      y_cnt_q <= '0;
    end else begin
      ctrl_reg_q <= ctrl_reg_d;
      state_q <= state_d;
      read_addr_q <= read_addr_d;
      write_addr_q <= write_addr_d;
      x_cnt_q <= x_cnt_d;
      y_cnt_q <= y_cnt_d;
    end
  end
  
  // Register writes
  always_comb begin
    ctrl_reg_d = ctrl_reg_q;
    obi_sbr_rsp_o = '0;
    
    if (obi_sbr_req_i.req && obi_sbr_req_i.a.we) begin
      case (obi_sbr_req_i.a.addr[5:2])
        0: ctrl_reg_d.src_addr = obi_sbr_req_i.a.wdata[AddrWidth-1:0];
        1: ctrl_reg_d.dst_addr = obi_sbr_req_i.a.wdata[AddrWidth-1:0];
        2: ctrl_reg_d.width = obi_sbr_req_i.a.wdata[15:0];
        3: ctrl_reg_d.height = obi_sbr_req_i.a.wdata[15:0];
        4: ctrl_reg_d.enable = obi_sbr_req_i.a.wdata[0];
        5: ctrl_reg_d.start = obi_sbr_req_i.a.wdata[0];
      endcase
    end
    
    // Register reads
    obi_sbr_rsp_o.rvalid = 1'b1;
    obi_sbr_rsp_o.gnt = 1'b1;
    obi_sbr_rsp_o.r.rdata = '0;
    
    if (obi_sbr_req_i.req && !obi_sbr_req_i.a.we) begin
      case (obi_sbr_req_i.a.addr[5:2])
        0: obi_sbr_rsp_o.r.rdata = ctrl_reg_q.src_addr;
        1: obi_sbr_rsp_o.r.rdata = ctrl_reg_q.dst_addr;
        2: obi_sbr_rsp_o.r.rdata = ctrl_reg_q.width;
        3: obi_sbr_rsp_o.r.rdata = ctrl_reg_q.height;
        4: obi_sbr_rsp_o.r.rdata = ctrl_reg_q.enable;
        5: obi_sbr_rsp_o.r.rdata = {31'b0, ctrl_reg_q.done};
      endcase
    end
  end
  
  // Edge detection FSM
  always_comb begin
    state_d = state_q;
    read_addr_d = read_addr_q;
    write_addr_d = write_addr_q;
    x_cnt_d = x_cnt_q;
    y_cnt_d = y_cnt_q;
    obi_mgr_req_o = '0;
    ctrl_reg_d.done = 1'b0;
    interrupt_o = 1'b0;
    
    case (state_q)
      IDLE: begin
        if (ctrl_reg_q.start && ctrl_reg_q.enable) begin
          read_addr_d = ctrl_reg_q.src_addr;
          write_addr_d = ctrl_reg_q.dst_addr;
          x_cnt_d = 1; // Start from (1,1) to avoid borders
          y_cnt_d = 1;
          state_d = READ_ROW_1;
        end
      end
      
      READ_ROW_1: begin
        obi_mgr_req_o.req = 1'b1;
        obi_mgr_req_o.a.addr = read_addr_q - ctrl_reg_q.width - 1;
        obi_mgr_req_o.a.we = 1'b0;
        
        if (obi_mgr_rsp_i.gnt) begin
          window[0][0] = obi_mgr_rsp_i.r.rdata[7:0];
          state_d = READ_ROW_2;
        end
      end
      
      READ_ROW_2: begin
        obi_mgr_req_o.req = 1'b1;
        obi_mgr_req_o.a.addr = read_addr_q - 1;
        obi_mgr_req_o.a.we = 1'b0;
        
        if (obi_mgr_rsp_i.gnt) begin
          window[1][0] = obi_mgr_rsp_i.r.rdata[7:0];
          state_d = READ_ROW_3;
        end
      end
      
      READ_ROW_3: begin
        obi_mgr_req_o.req = 1'b1;
        obi_mgr_req_o.a.addr = read_addr_q + ctrl_reg_q.width - 1;
        obi_mgr_req_o.a.we = 1'b0;
        
        if (obi_mgr_rsp_i.gnt) begin
          window[2][0] = obi_mgr_rsp_i.r.rdata[7:0];
          state_d = PROCESS;
        end
      end
      
      PROCESS: begin
        // Shift window and read new pixels
        for (int i = 0; i < 3; i++) begin
          for (int j = 0; j < 2; j++) begin
            window[i][j] = window[i][j+1];
          end
        end
        
        // Read remaining pixels for the window
        if (x_cnt_q < ctrl_reg_q.width - 1 && y_cnt_q < ctrl_reg_q.height - 1) begin
          obi_mgr_req_o.req = 1'b1;
          obi_mgr_req_o.a.addr = read_addr_q + ctrl_reg_q.width + 1;
          obi_mgr_req_o.a.we = 1'b0;
          
          if (obi_mgr_rsp_i.gnt) begin
            window[0][2] = obi_mgr_rsp_i.r.rdata[7:0];
            window[1][2] = obi_mgr_rsp_i.r.rdata[15:8];
            window[2][2] = obi_mgr_rsp_i.r.rdata[23:16];
            state_d = WRITE_RESULT;
          end
        end else begin
          state_d = WRITE_RESULT;
        end
      end
      
      WRITE_RESULT: begin
        obi_mgr_req_o.req = 1'b1;
        obi_mgr_req_o.a.addr = write_addr_q;
        obi_mgr_req_o.a.we = 1'b1;
        obi_mgr_req_o.a.wdata = {24'b0, result_pixel};
        obi_mgr_req_o.a.be = 4'b0001;
        
        if (obi_mgr_rsp_i.gnt) begin
          write_addr_d = write_addr_q + 1;
          read_addr_d = read_addr_q + 1;
          x_cnt_d = x_cnt_q + 1;
          
          if (x_cnt_q == ctrl_reg_q.width - 2) begin
            x_cnt_d = 1;
            y_cnt_d = y_cnt_q + 1;
            read_addr_d = read_addr_q + 2; // Move to next row
            
            if (y_cnt_q == ctrl_reg_q.height - 2) begin
              state_d = IDLE;
              ctrl_reg_d.done = 1'b1;
              interrupt_o = 1'b1;
            end else begin
              state_d = READ_ROW_1;
            end
          end else begin
            state_d = READ_ROW_1;
          end
        end
      end
    endcase
  end

endmodule