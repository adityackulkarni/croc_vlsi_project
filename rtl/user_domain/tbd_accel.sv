module tbd_accel #(
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned ADDR_WIDTH = 32
) (
    input  logic                     clk_i,
    input  logic                     rst_ni,

    // OBI Manager Interface (to access memory)
    output logic                     mgr_req_o,
    output logic                     mgr_we_o,
    output logic [ADDR_WIDTH-1:0]   mgr_addr_o,
    output logic [DATA_WIDTH-1:0]   mgr_wdata_o,
    output logic [3:0]              mgr_be_o,
    input  logic                    mgr_gnt_i,
    input  logic                    mgr_rvalid_i,
    input  logic [DATA_WIDTH-1:0]   mgr_rdata_i,

    // OBI Subordinate Interface (control registers)
    input  logic                    sub_port_req_i,
    input  logic                    sub_port_we_i,
    input  logic [ADDR_WIDTH-1:0]  sub_port_addr_i,
    input  logic [DATA_WIDTH-1:0]  sub_port_wdata_i,
    input  logic [3:0]             sub_port_be_i,
    output logic                   sub_port_gnt_o,
    output logic                   sub_port_rvalid_o,
    output logic [DATA_WIDTH-1:0] sub_port_rdata_o,

    // Interrupt
    output logic                   interrupt_o
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

    // FSM states
    typedef enum logic [2:0] {
        IDLE,
        READ,
        PROCESS,
        WRITE,
        DONE
    } state_e;

    state_e state_q, state_d;

    // Internal registers
    logic [ADDR_WIDTH-1:0] read_addr_q, read_addr_d;
    logic [ADDR_WIDTH-1:0] write_addr_q, write_addr_d;
    logic [15:0]           x_cnt_q, x_cnt_d;
    logic [15:0]           y_cnt_q, y_cnt_d;

    logic [7:0] pixel_window[0:8];
    logic [7:0] result_pixel;

    // Manager interface request signals registered
    logic                  mgr_req_d, mgr_req_q;
    logic                  mgr_we_d, mgr_we_q;
    logic [ADDR_WIDTH-1:0] mgr_addr_d, mgr_addr_q;
    logic [DATA_WIDTH-1:0] mgr_wdata_d, mgr_wdata_q;
    logic [3:0]            mgr_be_d, mgr_be_q;

    // Abs function
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

    // Control register read/write interface
    always_comb begin
        ctrl_reg_d = ctrl_reg_q;

        sub_port_gnt_o = 1'b1;       // always grant
        sub_port_rvalid_o = 1'b1;    // always valid
        sub_port_rdata_o = '0;

        if (sub_port_req_i) begin
            if (sub_port_we_i) begin
                case (sub_port_addr_i[5:2])  // assuming 4-byte aligned regs, 6 bits for addr
                    0: ctrl_reg_d.src_addr = sub_port_wdata_i;
                    1: ctrl_reg_d.dst_addr = sub_port_wdata_i;
                    2: ctrl_reg_d.width    = sub_port_wdata_i[15:0];
                    3: ctrl_reg_d.height   = sub_port_wdata_i[15:0];
                    4: ctrl_reg_d.enable   = sub_port_wdata_i[0];
                    5: ctrl_reg_d.start    = sub_port_wdata_i[0];
                endcase
            end else begin
                case (sub_port_addr_i[5:2])
                    0: sub_port_rdata_o = ctrl_reg_q.src_addr;
                    1: sub_port_rdata_o = ctrl_reg_q.dst_addr;
                    2: sub_port_rdata_o = {16'b0, ctrl_reg_q.width};
                    3: sub_port_rdata_o = {16'b0, ctrl_reg_q.height};
                    4: sub_port_rdata_o = {31'b0, ctrl_reg_q.enable};
                    5: sub_port_rdata_o = {31'b0, ctrl_reg_q.done};
                endcase
            end
        end
    end

    // Main FSM combinational
    always_comb begin
        state_d = state_q;
        ctrl_reg_d.done = 1'b0;

        mgr_req_d = 1'b0;
        mgr_we_d  = 1'b0;
        mgr_addr_d = '0;
        mgr_wdata_d = '0;
        mgr_be_d = 4'b0;

        read_addr_d = read_addr_q;
        write_addr_d = write_addr_q;
        x_cnt_d = x_cnt_q;
        y_cnt_d = y_cnt_q;
        interrupt_o = 1'b0;

        case(state_q)
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
                mgr_req_d = 1'b1;
                mgr_we_d = 1'b0;
                mgr_addr_d = read_addr_q;
                if (mgr_gnt_i) begin
                    // read pixel data from mgr_rdata_i
                    // For simplicity, replicate same byte 9 times as example (replace with real window read logic)
                    for (int i=0; i<9; i++) pixel_window[i] = mgr_rdata_i[7:0];
                    state_d = PROCESS;
                end
            end
            PROCESS: begin
                state_d = WRITE;
            end
            WRITE: begin
                mgr_req_d = 1'b1;
                mgr_we_d = 1'b1;
                mgr_addr_d = write_addr_q;
                mgr_wdata_d = {24'b0, result_pixel};
                mgr_be_d = 4'b0001;
                if (mgr_gnt_i) begin
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

    // Sequential logic registers
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            ctrl_reg_q <= '0;
            state_q <= IDLE;
            read_addr_q <= '0;
            write_addr_q <= '0;
            x_cnt_q <= '0;
            y_cnt_q <= '0;

            mgr_req_q <= 1'b0;
            mgr_we_q <= 1'b0;
            mgr_addr_q <= '0;
            mgr_wdata_q <= '0;
            mgr_be_q <= 4'b0;
        end else begin
            ctrl_reg_q <= ctrl_reg_d;
            state_q <= state_d;
            read_addr_q <= read_addr_d;
            write_addr_q <= write_addr_d;
            x_cnt_q <= x_cnt_d;
            y_cnt_q <= y_cnt_d;

            mgr_req_q <= mgr_req_d;
            mgr_we_q <= mgr_we_d;
            mgr_addr_q <= mgr_addr_d;
            mgr_wdata_q <= mgr_wdata_d;
            mgr_be_q <= mgr_be_d;
        end
    end

    // Output assignments
    assign mgr_req_o = mgr_req_q;
    assign mgr_we_o = mgr_we_q;
    assign mgr_addr_o = mgr_addr_q;
    assign mgr_wdata_o = mgr_wdata_q;
    assign mgr_be_o = mgr_be_q;

endmodule
