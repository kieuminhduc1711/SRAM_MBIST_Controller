`timescale 1ns / 1ps

module tb_mbist;

    parameter ADDR_WIDTH = 8;
    parameter DATA_WIDTH = 8;

    reg clk;
    reg rst_n;
    reg test_start;

    wire                  mbist_cs;
    wire                  mbist_we;
    wire [ADDR_WIDTH-1:0] mbist_addr;
    wire [DATA_WIDTH-1:0] mbist_din;
    wire [DATA_WIDTH-1:0] sram_dout;

    wire test_done;
    wire test_fail;

    // 1. Khoi tao khoi MBIST Controller
    mbist_controller #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_mbist (
        .clk        (clk),
        .rst_n      (rst_n),
        .test_start (test_start),
        .mbist_cs   (mbist_cs),
        .mbist_we   (mbist_we),
        .mbist_addr (mbist_addr),
        .mbist_din  (mbist_din),
        .sram_dout  (sram_dout),
        .test_done  (test_done),
        .test_fail  (test_fail)
    );

    // 2. Ket noi voi mo hinh SRAM (Sram_model_stub)
    Sram_model_stub u_sram (
        .clk  (clk),
        .cs   (mbist_cs),
        .we   (mbist_we),
        .addr (mbist_addr),
        .din  (mbist_din),
        .dout (sram_dout)
    );

    // 3. Tao xung Clock 50MHz (Chu ky 20ns)
    initial clk = 0;
    always #10 clk = ~clk;

    // 4. Kich ban kiem tra
    initial begin
        $display("=================================================");
        $display("[TB] Bat dau mo phong MBIST cho SRAM 256x8...");
        $display("=================================================");

        rst_n      = 0;
        test_start = 0;

        // Reset he thong trong 40ns
        #40;
        rst_n = 1;
        #20;

        // Phat xung test_start
        @(posedge clk);
        test_start = 1;
        @(posedge clk);
        test_start = 0;

        // Cho MBIST chay thuat toan March C- cho den khi test_done = 1
        @(posedge test_done);
        #50;

        // Danh gia ket qua
        if (test_fail == 1'b0) begin
            $display("=================================================");
            $display("[PASS] MBIST hoan thanh: SRAM 256x8 HOAN TOAN TOT!");
            $display("=================================================");
        end else begin
            $display("=================================================");
            $display("[FAIL] MBIST phat hien LOI trong bo nho SRAM!");
            $display("=================================================");
        end

        $stop; // Dung mo phong de quan sat Waveform tren ModelSim
    end

endmodule
