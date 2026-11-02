module sram_1rw #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 8
)(
    input  wire                  clk,
    input  wire                  cs,
    input  wire                  we,
    input  wire [ADDR_WIDTH-1:0] addr,
    input  wire [DATA_WIDTH-1:0] din,

    output reg  [DATA_WIDTH-1:0] dout
);

    localparam DEPTH = 2 ** ADDR_WIDTH;

    // Memory array: DEPTH words, DATA_WIDTH bits per word.
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    always @(posedge clk) begin
        if (cs) begin
            if (we) begin
                // Synchronous write.
                // dout holds its previous value.
                mem[addr] <= din;
            end
            else begin
                // Synchronous read with registered output.
                dout <= mem[addr];
            end
        end

        // When cs = 0, memory and dout hold their values.
    end

endmodule