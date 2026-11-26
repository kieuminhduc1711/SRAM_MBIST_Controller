`timescale 1ns / 1ps

// Moi instance = 1 MBIST + 1 SRAM co mot loi cu the
module mbist_fault_case #(
    parameter FT = 0,
    parameter FA = 0,
    parameter FB = 0,
    parameter AA = 0
)(
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    output wire done,
    output wire fail
);
    wire       cs, we;
    wire [7:0] a, d, q;

    mbist_controller #(.ADDR_WIDTH(8), .DATA_WIDTH(8)) u_m (
        .clk(clk), .rst_n(rst_n), .test_start(start),
        .mbist_cs(cs), .mbist_we(we), .mbist_addr(a), .mbist_din(d),
        .sram_dout(q), .test_done(done), .test_fail(fail)
    );

    sram_fault_model #(
        .ADDR_WIDTH(8), .DATA_WIDTH(8),
        .FAULT_TYPE(FT), .FAULT_ADDR(FA), .FAULT_BIT(FB), .AGGR_ADDR(AA)
    ) u_s (
        .clk(clk), .cs(cs), .we(we), .addr(a), .din(d), .dout(q)
    );
endmodule


module tb_mbist_fault;

    localparam NC = 17;

    // ---- Bang case: type / addr / bit / aggressor ----
    //  0: khong loi          1-3: SA0     4-6: SA1
    //  7-8: TF up            9-10: TF down
    // 11-12: CFin           13-14: CFid->0   15-16: CFid->1
    function integer f_type;
        input integer n;
        begin
            case (n)
                1, 2, 3:   f_type = 1;
                4, 5, 6:   f_type = 2;
                7, 8:      f_type = 3;
                9, 10:     f_type = 4;
                11, 12:    f_type = 5;
                13, 14:    f_type = 6;
                15, 16:    f_type = 7;
                default:   f_type = 0;
            endcase
        end
    endfunction

    function integer f_addr;
        input integer n;
        begin
            case (n)
                1: f_addr = 0;     2: f_addr = 255;   3: f_addr = 77;
                4: f_addr = 0;     5: f_addr = 128;   6: f_addr = 255;
                7: f_addr = 5;     8: f_addr = 255;
                9: f_addr = 5;    10: f_addr = 128;
                11: f_addr = 10;  12: f_addr = 20;
                13: f_addr = 10;  14: f_addr = 20;
                15: f_addr = 10;  16: f_addr = 20;
                default: f_addr = 0;
            endcase
        end
    endfunction

    function integer f_bit;
        input integer n;
        begin
            case (n)
                1: f_bit = 0;     2: f_bit = 7;     3: f_bit = 3;
                4: f_bit = 0;     5: f_bit = 3;     6: f_bit = 7;
                7: f_bit = 1;     8: f_bit = 7;
                9: f_bit = 2;    10: f_bit = 6;
                11: f_bit = 0;   12: f_bit = 4;
                13: f_bit = 1;   14: f_bit = 5;
                15: f_bit = 2;   16: f_bit = 6;
                default: f_bit = 0;
            endcase
        end
    endfunction

    function integer f_aggr;
        input integer n;
        begin
            case (n)
                11: f_aggr = 5;   12: f_aggr = 200;
                13: f_aggr = 5;   14: f_aggr = 200;
                15: f_aggr = 5;   16: f_aggr = 200;
                default: f_aggr = 0;
            endcase
        end
    endfunction

    reg  clk;
    reg  rst_n;
    reg  start;
    wire [NC-1:0] done_v;
    wire [NC-1:0] fail_v;

    genvar i;
    generate
        for (i = 0; i < NC; i = i + 1) begin : g_case
            mbist_fault_case #(
                .FT(f_type(i)), .FA(f_addr(i)), .FB(f_bit(i)), .AA(f_aggr(i))
            ) u (
                .clk(clk), .rst_n(rst_n), .start(start),
                .done(done_v[i]), .fail(fail_v[i])
            );
        end
    endgenerate

    initial clk = 0;
    always #10 clk = ~clk;

    initial begin
        #2000000;
        $display("[TIMEOUT] tb_mbist_fault");
        $stop;
    end

    integer n, err, det;

    initial begin
        rst_n = 0;
        start = 0;
        err   = 0;
        det   = 0;

        #45;
        rst_n = 1;
        #20;

        @(negedge clk);
        start = 1;
        @(negedge clk);
        start = 0;

        @(posedge done_v[0]);
        #1;

        for (n = 0; n < NC; n = n + 1) begin
            if (n == 0) begin
                if (fail_v[0]) begin
                    $display("FAIL: SRAM sach ma MBIST bao loi");
                    err = err + 1;
                end else
                    $display("PASS: SRAM sach -> khong bao loi");
            end else begin
                if (fail_v[n]) begin
                    det = det + 1;
                    $display("DETECTED case %0d: type=%0d addr=%0d bit=%0d aggr=%0d",
                             n, f_type(n), f_addr(n), f_bit(n), f_aggr(n));
                end else begin
                    err = err + 1;
                    $display("MISS     case %0d: type=%0d addr=%0d bit=%0d aggr=%0d",
                             n, f_type(n), f_addr(n), f_bit(n), f_aggr(n));
                end
            end
        end

        $display("Fault coverage = %0d/%0d = %0d%%", det, NC-1, (det*100)/(NC-1));
        if (err == 0) $display("ALL PASS");
        else          $display("TEST FAILED: %0d loi", err);

        $stop;
    end

endmodule
