`timescale 1ns/1ps

module tb_sram_1rw;

    // --------------------------------------------------------
    // 1. Signals
    // --------------------------------------------------------
    reg        clk;
    reg        cs;
    reg        we;
    reg  [7:0] addr;
    reg  [7:0] din;

    wire [7:0] din_second;
    wire [7:0] dout;
    wire [7:0] dout_second;

    assign din_second = ~din;

    // --------------------------------------------------------
    // 2. DUT instances
    // --------------------------------------------------------
    sram_1rw #(
        .ADDR_WIDTH(8),
        .DATA_WIDTH(8)
    ) dut (
        .clk  (clk),
        .cs   (cs),
        .we   (we),
        .addr (addr),
        .din  (din),
        .dout (dout)
    );

    sram_1rw #(
        .ADDR_WIDTH(8),
        .DATA_WIDTH(8)
    ) dut_second (
        .clk  (clk),
        .cs   (cs),
        .we   (we),
        .addr (addr),
        .din  (din_second),
        .dout (dout_second)
    );

    // --------------------------------------------------------
    // 3. Independent reference memories and expected outputs
    // --------------------------------------------------------
    reg [7:0] reference_mem        [0:255];
    reg [7:0] reference_mem_second [0:255];

    reg [7:0] expected_dout;
    reg [7:0] expected_dout_second;

    integer errors;
    integer transactions;

    integer i;
    integer p;
    integer b;

    integer seed;
    reg [31:0] random_word;
    reg [7:0]  pattern;

    // --------------------------------------------------------
    // 4. Clock: period = 10 ns
    // --------------------------------------------------------
    initial begin
        clk = 1'b0;
    end

    always #5 clk = ~clk;

    // --------------------------------------------------------
    // 5. Apply one transaction and check both SRAM instances
    // --------------------------------------------------------
    task apply_and_check;
        input       cs_value;
        input       we_value;
        input [7:0] address_value;
        input [7:0] data_value;

        reg [7:0] previous_dout;
        reg [7:0] previous_dout_second;

        begin
            // Drive inputs away from the sampling edge.
            @(negedge clk);

            previous_dout        = dout;
            previous_dout_second = dout_second;

            cs   = cs_value;
            we   = we_value;
            addr = address_value;
            din  = data_value;

            // Changing inputs must not immediately change dout.
            #1;

            if (dout !== previous_dout) begin
                errors = errors + 1;
                $display(
                    "FAIL DUT0: output changed before posedge, t=%0t",
                    $time
                );
            end

            if (dout_second !== previous_dout_second) begin
                errors = errors + 1;
                $display(
                    "FAIL DUT1: output changed before posedge, t=%0t",
                    $time
                );
            end

            // SRAM accepts the command at this edge.
            @(posedge clk);

            // Update the reference model using the applied command.
            if (cs_value) begin
                if (we_value) begin
                    reference_mem[address_value] = data_value;

                    reference_mem_second[address_value] =
                        ~data_value;

                    // Expected outputs hold during write.
                end
                else begin
                    expected_dout =
                        reference_mem[address_value];

                    expected_dout_second =
                        reference_mem_second[address_value];
                end
            end

            // Wait until DUT nonblocking assignments have updated.
            #1;

            transactions = transactions + 1;

            if (dout !== expected_dout) begin
                errors = errors + 1;
                $display(
                    "FAIL DUT0: t=%0t cs=%b we=%b addr=%h got=%h exp=%h",
                    $time, cs_value, we_value, address_value,
                    dout, expected_dout
                );
            end

            if (dout_second !== expected_dout_second) begin
                errors = errors + 1;
                $display(
                    "FAIL DUT1: t=%0t cs=%b we=%b addr=%h got=%h exp=%h",
                    $time, cs_value, we_value, address_value,
                    dout_second, expected_dout_second
                );
            end
        end
    endtask

    // --------------------------------------------------------
    // 6. Test sequence
    // --------------------------------------------------------
    initial begin
        cs   = 1'b0;
        we   = 1'b0;
        addr = 8'h00;
        din  = 8'h00;

        errors       = 0;
        transactions = 0;
        seed         = 32'h12345678;

        expected_dout        = 8'hxx;
        expected_dout_second = 8'hxx;

        // Initialize only the reference models.
        // Do not initialize the DUT memories.
        for (i = 0; i < 256; i = i + 1) begin
            reference_mem[i]        = 8'hxx;
            reference_mem_second[i] = 8'hxx;
        end

        // ----------------------------------------------------
        // TC08: Read an unwritten address
        // ----------------------------------------------------
        $display("TC08: Read unwritten memory");

        apply_and_check(1'b1, 1'b0, 8'h80, 8'h00);

        // ----------------------------------------------------
        // TC01 + TC07: Write, then read on the next cycle
        // ----------------------------------------------------
        $display("TC01 + TC07: Write then read");

        apply_and_check(1'b1, 1'b1, 8'h05, 8'hA5);
        apply_and_check(1'b1, 1'b0, 8'h05, 8'h00);

        // ----------------------------------------------------
        // TC04 + TC06: Overwrite and hold dout during write
        // ----------------------------------------------------
        $display("TC04 + TC06: Overwrite and output hold");

        apply_and_check(1'b1, 1'b1, 8'h05, 8'h3C);
        apply_and_check(1'b1, 1'b0, 8'h05, 8'h00);

        // ----------------------------------------------------
        // TC05: Disabled writes and disabled reads
        // ----------------------------------------------------
        $display("TC05: Chip-select disable");

        for (i = 0; i < 4; i = i + 1)
            apply_and_check(1'b0, 1'b1, 8'h05, 8'hFF);

        // Address 80 is still unwritten.
        // A disabled read must not change dout to X.
        apply_and_check(1'b0, 1'b0, 8'h80, 8'h00);

        // Confirm disabled writes did not corrupt address 05.
        apply_and_check(1'b1, 1'b0, 8'h05, 8'h00);

        // ----------------------------------------------------
        // TC03: Boundary addresses
        // ----------------------------------------------------
        $display("TC03: Boundary addresses");

        apply_and_check(1'b1, 1'b1, 8'h00, 8'h12);
        apply_and_check(1'b1, 1'b1, 8'hFF, 8'hE7);

        apply_and_check(1'b1, 1'b0, 8'h00, 8'h00);
        apply_and_check(1'b1, 1'b0, 8'hFF, 8'h00);

        // ----------------------------------------------------
        // TC02: Fill all addresses, then read all addresses
        // ----------------------------------------------------
        $display("TC02: Full address sweep");

        for (i = 0; i < 256; i = i + 1)
            apply_and_check(1'b1, 1'b1, i[7:0], i[7:0]);

        for (i = 0; i < 256; i = i + 1)
            apply_and_check(1'b1, 1'b0, i[7:0], 8'h00);

        // ----------------------------------------------------
        // Additional patterns: 00, FF, AA, 55
        // ----------------------------------------------------
        $display("Additional tests: Data patterns");

        for (p = 0; p < 4; p = p + 1) begin
            case (p)
                0: pattern = 8'h00;
                1: pattern = 8'hFF;
                2: pattern = 8'hAA;
                3: pattern = 8'h55;
            endcase

            for (i = 0; i < 256; i = i + 1)
                apply_and_check(1'b1, 1'b1, i[7:0], pattern);

            for (i = 0; i < 256; i = i + 1)
                apply_and_check(1'b1, 1'b0, i[7:0], 8'h00);
        end

        // ----------------------------------------------------
        // Additional test: Walking-one at address 3A
        // ----------------------------------------------------
        $display("Additional test: Walking-one");

        for (b = 0; b < 8; b = b + 1) begin
            pattern = 8'h01 << b;

            apply_and_check(1'b1, 1'b1, 8'h3A, pattern);
            apply_and_check(1'b1, 1'b0, 8'h3A, 8'h00);
        end

        // ----------------------------------------------------
        // TC09: Random commands with reference scoreboard
        // ----------------------------------------------------
        $display("TC09: Random transactions");

        for (i = 0; i < 1000; i = i + 1) begin
            random_word = $random(seed);

            apply_and_check(
                random_word[0],
                random_word[1],
                random_word[9:2],
                random_word[17:10]
            );
        end

        // Read every location after random traffic to detect
        // corruption that random reads might not have visited.
        for (i = 0; i < 256; i = i + 1)
            apply_and_check(1'b1, 1'b0, i[7:0], 8'h00);

        // ----------------------------------------------------
        // TC10: Explicit independent-instance example
        // DUT0 stores 96; DUT1 stores 69 at the same address.
        // Both instances were also checked throughout all tests.
        // ----------------------------------------------------
        $display("TC10: Independent instances");

        apply_and_check(1'b1, 1'b1, 8'h42, 8'h96);
        apply_and_check(1'b1, 1'b0, 8'h42, 8'h00);

        // Return to idle.
        apply_and_check(1'b0, 1'b0, 8'h00, 8'h00);

        // ----------------------------------------------------
        // 7. Final result
        // ----------------------------------------------------
        $display("----------------------------------------");
        $display("Transactions: %0d", transactions);
        $display("Errors      : %0d", errors);

        if (errors == 0)
            $display("PASS: All implemented SRAM tests passed.");
        else
            $display("FAIL: SRAM verification found errors.");

        $display("----------------------------------------");

        $finish;
    end

    // Watchdog: prevent a hung simulation.
    initial begin
        #100000;
        $display("FAIL: Simulation timeout.");
        $finish;
    end

endmodule