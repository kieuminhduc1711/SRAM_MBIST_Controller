
`timescale 1ns/1ps

module tb_sram;

    reg clk;
    reg cs;
    reg we;
    reg [7:0] addr;
    reg [7:0] din;
    wire [7:0] dout;

    integer i;
    integer errors;
    reg [7:0] saved_dout;

    sram_model_stub dut (
        .clk  (clk),
        .cs   (cs),
        .we   (we),
        .addr (addr),
        .din  (din),
        .dout (dout)
    );

    // Clock chu ky 10 ns
    initial clk = 0;
    always #5 clk = ~clk;

    // Ghi mot dia chi
    task write_mem;
        input [7:0] a;
        input [7:0] d;
        begin
            @(negedge clk);
            cs   = 1;
            we   = 1;
            addr = a;
            din  = d;

            @(posedge clk);
            #1;
        end
    endtask

    // Doc va kiem tra du lieu
    task check_read;
        input [7:0] a;
        input [7:0] expected;
        begin
            @(negedge clk);
            cs   = 1;
            we   = 0;
            addr = a;

            @(posedge clk);
            #1;

            if (dout !== expected) begin
                $display(
                    "FAIL READ addr=%h expected=%h actual=%h",
                    a, expected, dout
                );
                errors = errors + 1;
            end
            else begin
                $display(
                    "PASS READ addr=%h data=%h",
                    a, dout
                );
            end
        end
    endtask

    initial begin
        cs = 0;
        we = 0;
        addr = 0;
        din = 0;
        errors = 0;

        // TC01: Ghi va doc mot dia chi
        $display("TC01: Basic Write/Read");
        write_mem(8'h05, 8'hA5);
        check_read(8'h05, 8'hA5);

        // TC03: Hai dia chi bien
        $display("TC03: Boundary Addresses");
        write_mem(8'h00, 8'h12);
        write_mem(8'hFF, 8'hE7);
        check_read(8'h00, 8'h12);
        check_read(8'hFF, 8'hE7);

        // TC04: Ghi de cung dia chi
        $display("TC04: Overwrite");
        write_mem(8'h10, 8'h11);
        write_mem(8'h10, 8'h22);
        check_read(8'h10, 8'h22);

        // TC06: dout khong doi khi ghi
        $display("TC06: Output Holds During Write");
        check_read(8'h05, 8'hA5);
        saved_dout = dout;
        write_mem(8'h20, 8'hCC);

        if (dout !== saved_dout) begin
            $display("FAIL TC06: dout changed during write");
            errors = errors + 1;
        end
        else begin
            $display("PASS TC06");
        end

        // TC05: Idle nhieu chu ky
        $display("TC05: Chip Select Disabled");
        @(negedge clk);
        cs = 0;
        we = 0;

        repeat (3) begin
            @(posedge clk);
            #1;
            if (dout !== saved_dout) begin
                $display("FAIL TC05: dout changed in idle");
                errors = errors + 1;
            end
        end

        $display("TC05 idle check finished");

        // TC02: Kiem tra tat ca 256 dia chi = cách dùng Data Scrambling
        $display("TC02: All 256 Addresses");

        for (i = 0; i < 256; i = i + 1)
            write_mem(i, (i ^ 8'hA5)); // xor và ghi toàn bộ vô memo từng bit quét từ i=0->255

        for (i = 0; i < 256; i = i + 1)
            check_read(i, (i ^ 8'hA5));// check sau khi lấy dữ liệu từ memo ra để check add xem có trùng không

        // TC07: Doc ngay chu ky sau khi ghi
        $display("TC07: Read After Write");
        write_mem(8'h33, 8'h5A);
        check_read(8'h33, 8'h5A);

        if (errors == 0)
            $display("ALL SELECTED TESTS PASS");
        else
            $display("TESTS FAILED: %0d errors", errors);

        $finish;
    end

endmodule

