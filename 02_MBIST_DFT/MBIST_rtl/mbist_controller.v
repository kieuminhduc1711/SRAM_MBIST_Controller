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
    
    // Tín hiệu giao tiếp với cổng SRAM
    output reg                   mbist_cs,
    output reg                   mbist_we,
    output reg  [ADDR_WIDTH-1:0] mbist_addr,
    output reg  [DATA_WIDTH-1:0] mbist_din,
    input  wire [DATA_WIDTH-1:0] sram_dout,
    
    // Tín hiệu báo trạng thái kiểm tra
    output reg                   test_done,
    output reg                   test_fail
);

    // Dinh nghia cac trang thai FSM cho thuat toan March C-
    localparam [3:0]
        ST_IDLE   = 4'd0,
        ST_M0_W0  = 4'd1,   // M0: v (w0)   - Khoi tao toan bo o nho ve 0
        ST_M1_R0  = 4'd2,   // M1: ^ (r0)   - Doc kiem tra 0
        ST_M1_W1  = 4'd3,   // M1: ^ (w1)   - Ghi de 1, sau do tang dia chi
        ST_M2_R1  = 4'd4,   // M2: ^ (r1)   - Doc kiem tra 1
        ST_M2_W0  = 4'd5,   // M2: ^ (w0)   - Ghi de 0, sau do tang dia chi
        ST_M3_R0  = 4'd6,   // M3: v (r0)   - Doc kiem tra 0 (dia chi giam)
        ST_M3_W1  = 4'd7,   // M3: v (w1)   - Ghi de 1, sau do giam dia chi
        ST_M4_R1  = 4'd8,   // M4: v (r1)   - Doc kiem tra 1 (dia chi giam)
        ST_M4_W0  = 4'd9,   // M4: v (w0)   - Ghi de 0, sau do giam dia chi
        ST_M5_R0  = 4'd10,  // M5: v (r0)   - Doc kiem tra 0 toan bo bo nho
        ST_M5_CHK = 4'd11,  // M5: Cho chu ky cuoi de so sanh dia chi 255
        ST_DONE   = 4'd12;  // Hoan thanh

    reg [3:0] current_state, next_state;

    // Thanh ghi kiem tra tre 1 chu ky (Registered Read Latency = 1)
    reg                  exp_valid_d1;
    reg [DATA_WIDTH-1:0] exp_data_d1;

    // ------------------------------------------------------------------------
    // 1. Chuyen trang thai FSM (Tuan tu)
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            current_state <= ST_IDLE;
        else
            current_state <= next_state;
    end

    // ------------------------------------------------------------------------
    // 2. Logic chuyen trang thai tiep theo (To hop)
    // ------------------------------------------------------------------------
    always @(*) begin
        next_state = current_state;
        case (current_state)
            ST_IDLE: begin
                if (test_start)
                    next_state = ST_M0_W0;
            end

            // M0: Ghi 0 tu dia chi 0 -> 255
            ST_M0_W0: begin
                if (mbist_addr == 8'hFF)
                    next_state = ST_M1_R0;
            end

            // M1: Tang dan (Doc 0 roi Ghi 1 tai cung dia chi)
            ST_M1_R0: next_state = ST_M1_W1;
            ST_M1_W1: begin
                if (mbist_addr == 8'hFF)
                    next_state = ST_M2_R1;
                else
                    next_state = ST_M1_R0;
            end

            // M2: Tang dan (Doc 1 roi Ghi 0 tai cung dia chi)
            ST_M2_R1: next_state = ST_M2_W0;
            ST_M2_W0: begin
                if (mbist_addr == 8'hFF)
                    next_state = ST_M3_R0; // Chuyen sang pha giam dan tu 255
                else
                    next_state = ST_M2_R1;
            end

            // M3: Giam dan (Doc 0 roi Ghi 1 tai cung dia chi)
            ST_M3_R0: next_state = ST_M3_W1;
            ST_M3_W1: begin
                if (mbist_addr == 8'h00)
                    next_state = ST_M4_R1;
                else
                    next_state = ST_M3_R0;
            end

            // M4: Giam dan (Doc 1 roi Ghi 0 tai cung dia chi)
            ST_M4_R1: next_state = ST_M4_W0;
            ST_M4_W0: begin
                if (mbist_addr == 8'h00)
                    next_state = ST_M5_R0;
                else
                    next_state = ST_M4_R1;
            end

            // M5: Doc 0 toan bo tu 0 -> 255
            ST_M5_R0: begin
                if (mbist_addr == 8'hFF)
                    next_state = ST_M5_CHK;
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
    // 3. Logic dieu khien SRAM & Phat sinh dia chi / du lieu
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mbist_cs     <= 1'b0;
            mbist_we     <= 1'b0;
            mbist_addr   <= {ADDR_WIDTH{1'b0}};
            mbist_din    <= {DATA_WIDTH{1'b0}};
            test_done    <= 1'b0;
            exp_valid_d1 <= 1'b0;
            exp_data_d1  <= {DATA_WIDTH{1'b0}};
        end else begin
            case (current_state)
                ST_IDLE: begin
                    mbist_cs     <= 1'b0;
                    mbist_we     <= 1'b0;
                    mbist_addr   <= 8'h00;
                    mbist_din    <= 8'h00;
                    test_done    <= 1'b0;
                    exp_valid_d1 <= 1'b0;
                end

                // M0: Khoi tao ghi 0x00 vao toan bo SRAM
                ST_M0_W0: begin
                    mbist_cs     <= 1'b1;
                    mbist_we     <= 1'b1; // Write
                    mbist_din    <= 8'h00;
                    exp_valid_d1 <= 1'b0;
                    if (mbist_addr == 8'hFF)
                        mbist_addr <= 8'h00; // Reset ve 0 chuan bi cho M1
                    else
                        mbist_addr <= mbist_addr + 1'b1;
                end

                // M1: Doc 0x00
                ST_M1_R0: begin
                    mbist_cs     <= 1'b1;
                    mbist_we     <= 1'b0; // Read
                    exp_valid_d1 <= 1'b1;
                    exp_data_d1  <= 8'h00; // Ky vong doc duoc 0x00
                end
                // M1: Ghi 0xFF tai cung dia chi
                ST_M1_W1: begin
                    mbist_cs     <= 1'b1;
                    mbist_we     <= 1'b1; // Write
                    mbist_din    <= 8'hFF;
                    exp_valid_d1 <= 1'b0;
                    if (mbist_addr == 8'hFF)
                        mbist_addr <= 8'h00; // Chuan bi cho M2
                    else
                        mbist_addr <= mbist_addr + 1'b1;
                end

                // M2: Doc 0xFF
                ST_M2_R1: begin
                    mbist_cs     <= 1'b1;
                    mbist_we     <= 1'b0; // Read
                    exp_valid_d1 <= 1'b1;
                    exp_data_d1  <= 8'hFF; // Ky vong doc duoc 0xFF
                end
                // M2: Ghi 0x00 tai cung dia chi
                ST_M2_W0: begin
                    mbist_cs     <= 1'b1;
                    mbist_we     <= 1'b1; // Write
                    mbist_din    <= 8'h00;
                    exp_valid_d1 <= 1'b0;
                    if (mbist_addr == 8'hFF)
                        mbist_addr <= 8'hFF; // Giu nguyen 255 de bat dau dem giam o M3
                    else
                        mbist_addr <= mbist_addr + 1'b1;
                end

                // M3: Doc 0x00 (Giam dan)
                ST_M3_R0: begin
                    mbist_cs     <= 1'b1;
                    mbist_we     <= 1'b0; // Read
                    exp_valid_d1 <= 1'b1;
                    exp_data_d1  <= 8'h00;
                end
                // M3: Ghi 0xFF (Giam dan)
                ST_M3_W1: begin
                    mbist_cs     <= 1'b1;
                    mbist_we     <= 1'b1; // Write
                    mbist_din    <= 8'hFF;
                    exp_valid_d1 <= 1'b0;
                    if (mbist_addr == 8'h00)
                        mbist_addr <= 8'hFF; // Reset ve 255 de bat dau dem giam o M4
                    else
                        mbist_addr <= mbist_addr - 1'b1;
                end

                // M4: Doc 0xFF (Giam dan)
                ST_M4_R1: begin
                    mbist_cs     <= 1'b1;
                    mbist_we     <= 1'b0; // Read
                    exp_valid_d1 <= 1'b1;
                    exp_data_d1  <= 8'hFF;
                end
                // M4: Ghi 0x00 (Giam dan)
                ST_M4_W0: begin
                    mbist_cs     <= 1'b1;
                    mbist_we     <= 1'b1; // Write
                    mbist_din    <= 8'h00;
                    exp_valid_d1 <= 1'b0;
                    if (mbist_addr == 8'h00)
                        mbist_addr <= 8'h00; // Reset ve 0 de bat dau M5
                    else
                        mbist_addr <= mbist_addr - 1'b1;
                end

                // M5: Doc 0x00 lan cuoi
                ST_M5_R0: begin
                    mbist_cs     <= 1'b1;
                    mbist_we     <= 1'b0; // Read
                    exp_valid_d1 <= 1'b1;
                    exp_data_d1  <= 8'h00;
                    if (mbist_addr != 8'hFF)
                        mbist_addr <= mbist_addr + 1'b1;
                end
                ST_M5_CHK: begin
                    mbist_cs     <= 1'b0; // Nghi
                    exp_valid_d1 <= 1'b0;
                end

                // DONE: Hoan thanh
                ST_DONE: begin
                    mbist_cs     <= 1'b0;
                    mbist_we     <= 1'b0;
                    test_done    <= 1'b1;
                    exp_valid_d1 <= 1'b0;
                end
            endcase
        end
    end

    // ------------------------------------------------------------------------
    // 4. Bo so sanh (Comparator) & Co loi (Sticky Fail Flag)
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            test_fail <= 1'b0;
        end else if (current_state == ST_IDLE && test_start) begin
            test_fail <= 1'b0; // Xoa co khi bat dau dot test moi
        end else if (exp_valid_d1) begin
            if (sram_dout !== exp_data_d1) begin
                test_fail <= 1'b1; // Chi can 1 bit loi la chot luon co FAIL
            end
        end
    end

    // Ho tro hien thi ten trang thai tren Waveform ModelSim
    reg [79:0] state_name;
    always @(*) begin
        case (current_state)
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

endmodule
