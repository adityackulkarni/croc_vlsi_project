module user_edge_detect #(
  parameter obi_pkg::obi_cfg_t ObiCfg = obi_pkg::ObiDefaultConfig,
  parameter type obi_req_t = logic,
  parameter type obi_rsp_t = logic
) (
  input  logic    clk_i,
  input  logic    rst_ni,
  input  obi_req_t obi_req_i,
  output obi_rsp_t obi_rsp_o
);

  // Request pipeline registers
  logic        req_q, req_qq;
  logic        we_q, we_qq;
  logic [3:0]  addr_q, addr_qq;  // Extended to [3:0] for proper decoding
  logic [15:0] set_bits_accumulator;

  // Bit counter
  logic [15:0] wdata_cnt;
  always_comb begin
    wdata_cnt = '0;
    for (int i = 0; i < 32; i++)
      wdata_cnt += obi_req_i.a.wdata[i];
  end

  // OBI Response Logic
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      set_bits_accumulator <= '0;
      req_q  <= '0; req_qq  <= '0;
      we_q   <= '0; we_qq   <= '0;
      addr_q <= '0; addr_qq <= '0;
    end else begin
      // Pipeline stages for OBI protocol
      req_q  <= obi_req_i.req;
      req_qq <= req_q;
      
      we_q   <= obi_req_i.a.we;
      we_qq  <= we_q;
      
      addr_q <= obi_req_i.a.addr[3:0];
      addr_qq <= addr_q;

      // Accumulator update
      if (req_q && we_q) begin
        case (addr_q[3:2])
          2'h0: set_bits_accumulator <= '0;           // Reset on write to 0x0
          2'h1: set_bits_accumulator <= set_bits_accumulator + wdata_cnt; // Accumulate on write to 0x4
          default: ; // No action
        endcase
      end
    end
  end

  // Response generation
  always_comb begin
    obi_rsp_o.gnt = 1'b1;  // Always ready to accept requests
    
    obi_rsp_o.rvalid = req_qq;
    obi_rsp_o.r.rid  = '0;
    obi_rsp_o.r.r_optional = '0;
    
    if (req_qq) begin
      case (addr_qq[3:2])
        2'h2: begin  // Read from 0x8
          obi_rsp_o.r.rdata = {16'h0, set_bits_accumulator};
          obi_rsp_o.r.err = 1'b0;
        end
        default: begin
          obi_rsp_o.r.rdata = 32'hdeadbeef;
          obi_rsp_o.r.err = !we_qq; // Error on invalid reads
        end
      endcase
    end else begin
      obi_rsp_o.r.rdata = '0;
      obi_rsp_o.r.err = '0;
    end
  end

endmodule