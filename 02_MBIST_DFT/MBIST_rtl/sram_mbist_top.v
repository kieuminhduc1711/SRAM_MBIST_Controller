// ============================================================================
// Module : sram_mbist_top
// 1 MBIST controller dung chung, NUM_MEM SRAM 1RW, MUX Normal/Test,
// chon SRAM bang mem_sel. KHONG doi mem_sel khi MBIST dang chay.
// ============================================================================
module sram_mbist_top #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 8,
    parameter NUM_MEM    = 4,
    parameter SEL_WIDTH  = 2        // >= log2(NUM_MEM)
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // Dieu khien che do
    input  wire                  test_mode,     // 0: Normal, 1: MBIST
    input  wire                  test_start,
    input  wire [SEL_WIDTH-1:0]  mem_sel,

    // Cong truy cap chuc nang (Normal mode)
    input  wire                  func_cs,
    input  wire                  func_we,
    input  wire [ADDR_WIDTH-1:0] func_addr,
    input  wire [DATA_WIDTH-1:0] func_din,
    output wire [DATA_WIDTH-1:0] func_dout,

    // Ket qua MBIST
    output wire                  test_done,
    output wire                  test_fail,
    output reg  [NUM_MEM-1:0]    mem_done_vec,  // SRAM nao da test xong
    output reg  [NUM_MEM-1:0]    mem_fail_vec   // SRAM nao bi loi
);

    wire                  m_cs, m_we;
    wire [ADDR_WIDTH-1:0] m_addr;
    wire [DATA_WIDTH-1:0] m_din;
    wire [DATA_WIDTH-1:0] sel_dout;

    mbist_controller #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_mbist (
        .clk        (clk),
        .rst_n      (rst_n),
        .test_start (test_start & test_mode),
        .mbist_cs   (m_cs),
        .mbist_we   (m_we),
        .mbist_addr (m_addr),
        .mbist_din  (m_din),
        .sram_dout  (sel_dout),
        .test_done  (test_done),
        .test_fail  (test_fail)
    );

    // MUX Normal / Test
    wire                  cs_i   = test_mode ? m_cs   : func_cs;
    wire                  we_i   = test_mode ? m_we   : func_we;
    wire [ADDR_WIDTH-1:0] addr_i = test_mode ? m_addr : func_addr;
    wire [DATA_WIDTH-1:0] din_i  = test_mode ? m_din  : func_din;

    // NUM_MEM SRAM, chi SRAM duoc chon moi nhan cs
    wire [NUM_MEM*DATA_WIDTH-1:0] dout_flat;

    genvar g;
    generate
        for (g = 0; g < NUM_MEM; g = g + 1) begin : g_mem
            sram_1rw #(
                .ADDR_WIDTH(ADDR_WIDTH),
                .DATA_WIDTH(DATA_WIDTH)
            ) u_sram (
                .clk  (clk),
                .cs   (cs_i & (mem_sel == g)),
                .we   (we_i),
                .addr (addr_i),
                .din  (din_i),
                .dout (dout_flat[g*DATA_WIDTH +: DATA_WIDTH])
            );
        end
    endgenerate

    assign sel_dout  = dout_flat[mem_sel*DATA_WIDTH +: DATA_WIDTH];
    assign func_dout = sel_dout;

    // Luu ket qua tung SRAM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_done_vec <= {NUM_MEM{1'b0}};
            mem_fail_vec <= {NUM_MEM{1'b0}};
        end else if (test_start && test_mode) begin
            mem_done_vec[mem_sel] <= 1'b0;
            mem_fail_vec[mem_sel] <= 1'b0;
        end else if (test_done) begin
            mem_done_vec[mem_sel] <= 1'b1;
            mem_fail_vec[mem_sel] <= test_fail;
        end
    end

endmodule
