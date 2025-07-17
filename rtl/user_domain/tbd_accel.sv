module tbd_accel #( 
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned ADDR_WIDTH = 32
) (
    input  logic                     clk_i,
    input  logic                     rst_ni,

    // OBI Manager Interface (to access memory)
    output logic                     obi_mgr_req_o,
    output logic                     obi_mgr_we_o,
    output logic [ADDR_WIDTH-1:0]   obi_mgr_addr_o,
    output logic [DATA_WIDTH-1:0]   obi_mgr_wdata_o,
    output logic [3:0]               obi_mgr_be_o,
    input  logic                    obi_mgr_gnt_i,
    input  logic                    obi_mgr_rvalid_i,
    input  logic [DATA_WIDTH-1:0]   obi_mgr_rdata_i,

    // OBI Subordinate Interface (for control registers)
    input  logic                    obi_sbr_req_i,
    input  logic                    obi_sbr_we_i,
    input  logic [ADDR_WIDTH-1:0]   obi_sbr_addr_i,
    input  logic [DATA_WIDTH-1:0]   obi_sbr_wdata_i,
    input  logic [3:0]               obi_sbr_be_i,
    output logic                    obi_sbr_gnt_o,
    output logic                    obi_sbr_rvalid_o,
    output logic [DATA_WIDTH-1:0]   obi_sbr_rdata_o,

    // Interrupt
    output logic                     interrupt_o
);

    // Control registers
    typedef struct packed {
        logic [ADDR_WIDTH-1:0] src_addr;
        logic [ADDR_WIDTH-1:0] dst_addr;
        logic [15:0]           width;
        logic [15:0]           height;
        logic                  start;
        logic                  done;
        logic                  enable;
    } ctrl_reg_t;

    ctrl_reg_t ctrl_reg_q, ctrl_reg_d;

    // State machine
    typedef enum logic [2:0] {
        IDLE,
        READ,
        PROCESS,
        WRITE,
        DONE
    } state_e;

    state_e state_q, state_d;

    // Internal variables
    logic [ADDR_WIDTH-1:0] read_addr_q, read_addr_d;
    logic [ADDR_WIDTH-1:0] write_addr_q, write_addr_d;
    logic [15:0]           x_cnt_q, x_cnt_d;
    logic [15:0]           y_cnt_q, y_cnt_d;
    logic [7:0]            pixel_window[0:8];
    logic [7:0]            result_pixel;

    // OBI manager interface signals (registered outputs)
    logic                  obi_req_d_req,  obi_req_q_req;
    logic                  obi_req_d_we,   obi_req_q_we;
    logic [ADDR_WIDTH-1:0] obi_req_d_addr, obi_req_q_addr;
    logic [DATA_WIDTH-1:0] obi_req_d_wdata, obi_req_q_wdata;
    logic [3:0]            obi_req_d_be,   obi_req_q_be;

    // Absolute value function
    function automatic int abs_val(int val);
        return (val < 0) ? -val : val;
    endfunction

    // Sobel kernel computation
    always_comb begin
        int gx, gy;
        gx = (pixel_window[2] + 2*pixel_window[5] + pixel_window[8]) - (pixel_window[0] + 2*pixel_window[3] + pixel_window[6]);
        gy = (pixel_window[6] + 2*pixel_window[7] + pixel_window[8]) - (pixel_window[0] + 2*pixel_window[1] + pixel_window[2]);
        result_pixel = ((abs_val(gx) + abs_val(gy)) >> 1 > 8'h80) ? 8'hFF : 8'h00;
    end

    // Control register read/write
    always_comb begin
        ctrl_reg_d = ctrl_reg_q;
        obi_sbr_gnt_o = 1'b1;
        obi_sbr_rvalid_o = 1'b1;
        obi_sbr_rdata_o = '0;

        if (obi_sbr_req_i) begin
            if (obi_sbr_we_i) begin
                case (obi_sbr_addr_i[5:2])
                    0: ctrl_reg_d.src_addr = obi_sbr_wdata_i;
                    1: ctrl_reg_d.dst_addr = obi_sbr_wdata_i;
                    2: ctrl_reg_d.width    = obi_sbr_wdata_i[15:0];
                    3: ctrl_reg_d.height   = obi_sbr_wdata_i[15:0];
                    4: ctrl_reg_d.enable   = obi_sbr_wdata_i[0];
                    5: ctrl_reg_d.start    = obi_sbr_wdata_i[0];
                endcase
            end else begin
                case (obi_sbr_addr_i[5:2])
                    0: obi_sbr_rdata_o = ctrl_reg_q.src_addr;
                    1: obi_sbr_rdata_o = ctrl_reg_q.dst_addr;
                    2: obi_sbr_rdata_o = {16'b0, ctrl_reg_q.width};
                    3: obi_sbr_rdata_o = {16'b0, ctrl_reg_q.height};
                    4: obi_sbr_rdata_o = {31'b0, ctrl_reg_q.enable};
                    5: obi_sbr_rdata_o = {31'b0, ctrl_reg_q.done};
                endcase
            end
        end
    end

    // FSM next state logic
    always_comb begin
        state_d = state_q;
        ctrl_reg_d.done = 1'b0;

        obi_req_d_req = 1'b0;
        obi_req_d_we  = 1'b0;
        obi_req_d_addr = '0;
        obi_req_d_wdata = '0;
        obi_req_d_be    = 4'b0000;

        read_addr_d = read_addr_q;
        write_addr_d = write_addr_q;
        x_cnt_d = x_cnt_q;
        y_cnt_d = y_cnt_q;
        interrupt_o = 1'b0;

        case (state_q)
            IDLE: begin
                if (ctrl_reg_q.start && ctrl_reg_q.enable) begin
                    state_d = READ;
                    read_addr_d = ctrl_reg_q.src_addr;
                    write_addr_d = ctrl_reg_q.dst_addr;
                    x_cnt_d = 1;
                    y_cnt_d = 1;
                end
            end
            READ: begin
                obi_req_d_req  = 1'b1;
                obi_req_d_we   = 1'b0;
                obi_req_d_addr = read_addr_q;
                if (obi_mgr_gnt_i) begin
                    // Read pixel byte (assuming 8-bit pixel in LSB)
                    // NOTE: Ideally should read 9 pixels for 3x3 window from memory
                    // This simplified model only reads one pixel repeatedly.
                    for (int i = 0; i < 9; i++) pixel_window[i] = obi_mgr_rdata_i[7:0];
                    state_d = PROCESS;
                end
            end
            PROCESS: begin
                state_d = WRITE;
            end
            WRITE: begin
                obi_req_d_req   = 1'b1;
                obi_req_d_we    = 1'b1;
                obi_req_d_addr  = write_addr_q;
                obi_req_d_wdata = {24'b0, result_pixel};
                obi_req_d_be    = 4'b0001;
                if (obi_mgr_gnt_i) begin
                    x_cnt_d = x_cnt_q + 1;
                    read_addr_d = read_addr_q + 1;
                    write_addr_d = write_addr_q + 1;
                    if (x_cnt_q == ctrl_reg_q.width - 2) begin
                        x_cnt_d = 1;
                        y_cnt_d = y_cnt_q + 1;
                        if (y_cnt_q == ctrl_reg_q.height - 2) begin
                            state_d = DONE;
                        end else begin
                            state_d = READ;
                        end
                    end else begin
                        state_d = READ;
                    end
                end
            end
            DONE: begin
                ctrl_reg_d.done = 1'b1;
                interrupt_o = 1'b1;
                state_d = IDLE;
            end
        endcase
    end

    // Sequential logic
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            ctrl_reg_q <= '0;
            state_q <= IDLE;
            read_addr_q <= '0;
            write_addr_q <= '0;
            x_cnt_q <= '0;
            y_cnt_q <= '0;
            obi_req_q_req <= 1'b0;
            obi_req_q_we <= 1'b0;
            obi_req_q_addr <= '0;
            obi_req_q_wdata <= '0;
            obi_req_q_be <= 4'b0000;
        end else begin
            ctrl_reg_q <= ctrl_reg_d;
            state_q <= state_d;
            read_addr_q <= read_addr_d;
            write_addr_q <= write_addr_d;
            x_cnt_q <= x_cnt_d;
            y_cnt_q <= y_cnt_d;
            obi_req_q_req <= obi_req_d_req;
            obi_req_q_we  <= obi_req_d_we;
            obi_req_q_addr <= obi_req_d_addr;
            obi_req_q_wdata <= obi_req_d_wdata;
            obi_req_q_be <= obi_req_d_be;
        end
    end

    // Assign output signals for OBI manager interface
    assign obi_mgr_req_o   = obi_req_q_req;
    assign obi_mgr_we_o    = obi_req_q_we;
    assign obi_mgr_addr_o  = obi_req_q_addr;
    assign obi_mgr_wdata_o = obi_req_q_wdata;
    assign obi_mgr_be_o    = obi_req_q_be;

endmodule
