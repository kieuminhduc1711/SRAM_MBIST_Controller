
module sram_model_stub (
    input        clk,
    input        cs,
    input        we,
    input  [7:0] addr,
    input  [7:0] din,
    output reg [7:0] dout
);

    reg [7:0] mem [0:255];

    always @(posedge clk) begin
        if (cs) begin
            if (we) begin
                mem[addr] <= din;
            end
            else begin
                dout <= mem[addr];
            end
        end
    end

endmodule

