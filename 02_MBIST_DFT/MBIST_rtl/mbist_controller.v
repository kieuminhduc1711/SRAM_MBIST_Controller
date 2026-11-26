// ============================================================================
// Module : mbist_controller
// Project: SRAM MBIST Controller (March C- Algorithm)
// Spec   : SRAM-SPEC-001 (1RW Synchronous SRAM 256x8)
// ============================================================================


module mbist_controller #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 8
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  test_start,

    // Giao tiep voi SRAM
    output wire                  mbist_cs,
    output wire                  mbist_we,
    output wire [ADDR_WIDTH-1:0] mbist_addr,
    output wire [DATA_WIDTH-1:0] mbist_din,
    input  wire [DATA_WIDTH-1:0] sram_dout,

    // Trang thai
    output wire                  test_done,
    output reg                   test_fail
);

    localparam [ADDR_WIDTH-1:0] A_MAX = {ADDR_WIDTH{1'b1}};
    localparam [ADDR_WIDTH-1:0] A_MIN = {ADDR_WIDTH{1'b0}};
    localparam [DATA_WIDTH-1:0] D0    = {DATA_WIDTH{1'b0}};
    localparam [DATA_WIDTH-1:0] D1    = {DATA_WIDTH{1'b1}};

    localparam [3:0]
        ST_IDLE   = 4'd0,
        ST_M0_W0  = 4'd1,   // M0: any  (w0)
        ST_M1_R0  = 4'd2,   // M1: up   (r0)
        ST_M1_W1  = 4'd3,   // M1: up   (w1)
        ST_M2_R1  = 4'd4,   // M2: up   (r1)
        ST_M2_W0  = 4'd5,   // M2: up   (w0)
        ST_M3_R0  = 4'd6,   // M3: down (r0)
        ST_M3_W1  = 4'd7,   // M3: down (w1)
        ST_M4_R1  = 4'd8,   // M4: down (r1)
        ST_M4_W0  = 4'd9,   // M4: down (w0)
        ST_M5_R0  = 4'd10,  // M5: any  (r0)
        ST_M5_CHK = 4'd11,  // cho so sanh lan doc cuoi
        ST_DONE   = 4'd12;

    reg [3:0]            state, next_state;
    reg [ADDR_WIDTH-1:0] addr_q, addr_n;

    // Thanh ghi kiem tra tre 1 chu ky (khop read latency cua SRAM)
    reg                  exp_valid_q;
    reg [DATA_WIDTH-1:0] exp_data_q;

    // ------------------------------------------------------------------------
    // Giai ma trang thai -> tin hieu dieu khien
    // ------------------------------------------------------------------------
    wire st_write = (state == ST_M0_W0) || (state == ST_M1_W1) ||
                    (state == ST_M2_W0) || (state == ST_M3_W1) ||
                    (state == ST_M4_W0);

    wire st_read  = (state == ST_M1_R0) || (state == ST_M2_R1) ||
                    (state == ST_M3_R0) || (state == ST_M4_R1) ||
                    (state == ST_M5_R0);

    assign mbist_cs   = st_write | st_read;
    assign mbist_we   = st_write;
    assign mbist_addr = addr_q;
    assign mbist_din  = ((state == ST_M1_W1) || (state == ST_M3_W1)) ? D1 : D0;

    // Gia tri ky vong cua phep doc dang phat ra
    wire [DATA_WIDTH-1:0] exp_data_now =
        ((state == ST_M2_R1) || (state == ST_M4_R1)) ? D1 : D0;

    assign test_done = (state == ST_DONE);

    // ------------------------------------------------------------------------
    // Next-state va next-address (to hop)
    // ------------------------------------------------------------------------
    always @(*) begin
        next_state = state;
        addr_n     = addr_q;
        case (state)
            ST_IDLE: begin
                addr_n = A_MIN;
                if (test_start)
                    next_state = ST_M0_W0;
            end

            // M0: ghi 0 tu 0 -> max
            ST_M0_W0: begin
                if (addr_q == A_MAX) begin
                    next_state = ST_M1_R0;
                    addr_n     = A_MIN;
                end else
                    addr_n = addr_q + 1'b1;
            end

            // M1: tang dan (r0, w1)
            ST_M1_R0: next_state = ST_M1_W1;
            ST_M1_W1: begin
                if (addr_q == A_MAX) begin
                    next_state = ST_M2_R1;
                    addr_n     = A_MIN;
                end else begin
                    next_state = ST_M1_R0;
                    addr_n     = addr_q + 1'b1;
                end
            end

            // M2: tang dan (r1, w0)
            ST_M2_R1: next_state = ST_M2_W0;
            ST_M2_W0: begin
                if (addr_q == A_MAX)
                    next_state = ST_M3_R0;      // giu addr = max, bat dau giam
                else begin
                    next_state = ST_M2_R1;
                    addr_n     = addr_q + 1'b1;
                end
            end

            // M3: giam dan (r0, w1)
            ST_M3_R0: next_state = ST_M3_W1;
            ST_M3_W1: begin
                if (addr_q == A_MIN) begin
                    next_state = ST_M4_R1;
                    addr_n     = A_MAX;         // M4 cung giam, bat dau tu max
                end else begin
                    next_state = ST_M3_R0;
                    addr_n     = addr_q - 1'b1;
                end
            end

            // M4: giam dan (r1, w0)
            ST_M4_R1: next_state = ST_M4_W0;
            ST_M4_W0: begin
                if (addr_q == A_MIN) begin
                    next_state = ST_M5_R0;
                    addr_n     = A_MIN;         // M5 tang tu 0
                end else begin
                    next_state = ST_M4_R1;
                    addr_n     = addr_q - 1'b1;
                end
            end

            // M5: doc 0 toan bo, tang dan
            ST_M5_R0: begin
                if (addr_q == A_MAX)
                    next_state = ST_M5_CHK;
                else
                    addr_n = addr_q + 1'b1;
            end

            ST_M5_CHK: next_state = ST_DONE;

            ST_DONE: begin
                if (!test_start)
                    next_state = ST_IDLE;
            end

            default: next_state = ST_IDLE;
        endcase
    end

    // ------------------------------------------------------------------------
    // Thanh ghi: state, dia chi, pipeline ky vong, co FAIL
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= ST_IDLE;
            addr_q      <= A_MIN;
            exp_valid_q <= 1'b0;
            exp_data_q  <= D0;
            test_fail   <= 1'b0;
        end else begin
            state       <= next_state;
            addr_q      <= addr_n;
            exp_valid_q <= st_read;
            exp_data_q  <= exp_data_now;

            if (state == ST_IDLE && test_start) begin
                test_fail <= 1'b0;                  // bat dau dot test moi
            end else if (exp_valid_q) begin
                // Neu sram_dout la X thi phep == cho X -> nhanh else -> bao FAIL
                if (sram_dout == exp_data_q)
                    test_fail <= test_fail;
                else
                    test_fail <= 1'b1;              // sticky
            end
        end
    end

`ifndef SYNTHESIS
    // Hien thi ten trang thai tren waveform
    reg [79:0] state_name;
    always @(*) begin
        case (state)
            ST_IDLE   : state_name = "IDLE";
            ST_M0_W0  : state_name = "M0_w0";
            ST_M1_R0  : state_name = "M1_r0";
            ST_M1_W1  : state_name = "M1_w1";
            ST_M2_R1  : state_name = "M2_r1";
            ST_M2_W0  : state_name = "M2_w0";
            ST_M3_R0  : state_name = "M3_r0";
            ST_M3_W1  : state_name = "M3_w1";
            ST_M4_R1  : state_name = "M4_r1";
            ST_M4_W0  : state_name = "M4_w0";
            ST_M5_R0  : state_name = "M5_r0";
            ST_M5_CHK : state_name = "M5_chk";
            ST_DONE   : state_name = "DONE";
            default   : state_name = "UNKNOWN";
        endcase
    end
`endif

endmodule
