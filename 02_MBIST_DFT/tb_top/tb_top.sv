`timescale 1ns / 1ps

module tb_top;

    localparam AW = 8;
    localparam DW = 8;
    localparam NM = 4;
    localparam SW = 2;

    reg                 clk;
    reg                 rst_n;
    reg                 test_mode;
    reg                 test_start;
    reg  [SW-1:0]       mem_sel;
    reg                 func_cs;
    reg                 func_we;
    reg  [AW-1:0]       func_addr;
    reg  [DW-1:0]       func_din;
    wire [DW-1:0]       func_dout;
    wire                test_done;
    wire                test_fail;
    wire [NM-1:0]       mem_done_vec;
    wire [NM-1:0]       mem_fail_vec;

    integer errors;
    integer g, k;

    sram_mbist_top #(
        .ADDR_WIDTH(AW), .DATA_WIDTH(DW), .NUM_MEM(NM), .SEL_WIDTH(SW)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .test_mode(test_mode), .test_start(test_start), .mem_sel(mem_sel),
        .func_cs(func_cs), .func_we(func_we), .func_addr(func_addr),
        .func_din(func_din), .func_dout(func_dout),
        .test_done(test_done), .test_fail(test_fail),
        .mem_done_vec(mem_done_vec), .mem_fail_vec(mem_fail_vec)
    );

    initial clk = 0;
    always #10 clk = ~clk;

    // Watchdog
    initial begin
        #5000000;
        $display("[TIMEOUT] tb_top");
        $stop;
    end

    // ---- Normal mode: ghi 1 SRAM ----
    task func_write;
        input [SW-1:0] m;
        input [AW-1:0] a;
        input [DW-1:0] d;
        begin
            @(negedge clk);
            mem_sel   = m;
            func_cs   = 1'b1;
            func_we   = 1'b1;
            func_addr = a;
            func_din  = d;
            @(negedge clk);
            func_cs   = 1'b0;
            func_we   = 1'b0;
        end
    endtask

    // ---- Normal mode: doc va kiem tra ----
    task func_check;
        input [SW-1:0] m;
        input [AW-1:0] a;
        input [DW-1:0] expected;
        begin
            @(negedge clk);
            mem_sel   = m;
            func_cs   = 1'b1;
            func_we   = 1'b0;
            func_addr = a;
            @(negedge clk);
            func_cs   = 1'b0;
            if (func_dout !== expected) begin
                $display("FAIL: mem%0d addr=%h expected=%h actual=%h", m, a, expected, func_dout);
                errors = errors + 1;
            end else begin
                $display("PASS: mem%0d addr=%h data=%h", m, a, func_dout);
            end
        end
    endtask

    // ---- Chay MBIST cho SRAM m ----
    task run_mbist;
        input [SW-1:0] m;
        begin
            @(negedge clk);
            mem_sel    = m;
            test_mode  = 1'b1;
            test_start = 1'b0;
            @(negedge clk);
            test_start = 1'b1;
            @(negedge clk);
            test_start = 1'b0;

            @(posedge test_done);
            @(negedge clk);
            @(negedge clk);          // cho mem_done/mem_fail duoc chot

            if (test_fail !== 1'b0) begin
                $display("FAIL: MBIST bao loi tren SRAM%0d sach", m);
                errors = errors + 1;
            end else begin
                $display("PASS: MBIST SRAM%0d", m);
            end
            if (mem_done_vec[m] !== 1'b1) begin
                $display("FAIL: mem_done_vec[%0d] chua len 1", m);
                errors = errors + 1;
            end
            if (mem_fail_vec[m] !== 1'b0) begin
                $display("FAIL: mem_fail_vec[%0d] = 1", m);
                errors = errors + 1;
            end

            test_mode = 1'b0;
        end
    endtask

    initial begin
        errors     = 0;
        rst_n      = 0;
        test_mode  = 0;
        test_start = 0;
        mem_sel    = 0;
        func_cs    = 0;
        func_we    = 0;
        func_addr  = 0;
        func_din   = 0;

        #45;
        rst_n = 1;
        #20;

        // T1: Normal mode - moi SRAM luu gia tri rieng tai cung dia chi
        $display("T1: Normal mode, mem_sel tach SRAM");
        for (g = 0; g < NM; g = g + 1)
            func_write(g, 8'h10, 8'hA0 + g);
        for (g = 0; g < NM; g = g + 1)
            func_check(g, 8'h10, 8'hA0 + g);

        // T2: MBIST lan luot tung SRAM. SRAM chua test phai khong bi anh huong.
        $display("T2: MBIST tung SRAM, kiem tra cach ly");
        for (g = 0; g < NM; g = g + 1) begin
            run_mbist(g);
            func_check(g, 8'h10, 8'h00);              // March C- ket thuc bang 0
            for (k = g + 1; k < NM; k = k + 1)
                func_check(k, 8'h10, 8'hA0 + k);      // SRAM khac van nguyen
        end

        if (errors == 0 && mem_fail_vec == {NM{1'b0}} && mem_done_vec == {NM{1'b1}})
            $display("ALL TESTS PASS");
        else
            $display("TESTS FAILED: %0d errors, done=%b fail=%b", errors, mem_done_vec, mem_fail_vec);

        $stop;
    end

endmodule
