// ============================================================================
// SRAM 1RW co chen loi (chi dung de mo phong, KHONG dua vao synthesis)
//
// FAULT_TYPE:
//   0 : khong loi
//   1 : SA0   - bit FAULT_BIT cua o FAULT_ADDR luon = 0
//   2 : SA1   - bit FAULT_BIT cua o FAULT_ADDR luon = 1
//   3 : TF up   - o FAULT_ADDR khong chuyen duoc 0 -> 1
//   4 : TF down - o FAULT_ADDR khong chuyen duoc 1 -> 0
//   5 : CFin  - aggressor (AGGR_ADDR) chuyen 0->1 thi victim (FAULT_ADDR) bi dao
//   6 : CFid  - aggressor chuyen 0->1 thi victim bi ep = 0
//   7 : CFid  - aggressor chuyen 0->1 thi victim bi ep = 1
// Coupling lam tren cung bit FAULT_BIT cua 2 dia chi khac nhau.
// ============================================================================
module sram_fault_model #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 8,
    parameter FAULT_TYPE = 0,
    parameter FAULT_ADDR = 0,
    parameter FAULT_BIT  = 0,
    parameter AGGR_ADDR  = 0
)(
    input  wire                  clk,
    input  wire                  cs,
    input  wire                  we,
    input  wire [ADDR_WIDTH-1:0] addr,
    input  wire [DATA_WIDTH-1:0] din,
    output reg  [DATA_WIDTH-1:0] dout
);

    reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];
    reg [DATA_WIDTH-1:0] wdata;
    reg [DATA_WIDTH-1:0] rdata;
    reg                  old_bit;
    integer              k;

    initial begin
        for (k = 0; k < (1<<ADDR_WIDTH); k = k + 1)
            mem[k] = {DATA_WIDTH{1'b0}};
        dout = {DATA_WIDTH{1'b0}};
    end

    always @(posedge clk) begin
        if (cs) begin
            if (we) begin
                wdata   = din;
                old_bit = mem[addr][FAULT_BIT];

                // Loi tren chinh o dang ghi (SA, TF)
                if (addr == FAULT_ADDR) begin
                    case (FAULT_TYPE)
                        1: wdata[FAULT_BIT] = 1'b0;
                        2: wdata[FAULT_BIT] = 1'b1;
                        3: if (!old_bit &&  din[FAULT_BIT]) wdata[FAULT_BIT] = 1'b0;
                        4: if ( old_bit && !din[FAULT_BIT]) wdata[FAULT_BIT] = 1'b1;
                        default: ;
                    endcase
                end

                mem[addr] = wdata;

                // Coupling: aggressor len 0->1 tac dong len victim
                if (FAULT_TYPE >= 5 && addr == AGGR_ADDR &&
                    !old_bit && wdata[FAULT_BIT]) begin
                    case (FAULT_TYPE)
                        5: mem[FAULT_ADDR][FAULT_BIT] = ~mem[FAULT_ADDR][FAULT_BIT];
                        6: mem[FAULT_ADDR][FAULT_BIT] = 1'b0;
                        7: mem[FAULT_ADDR][FAULT_BIT] = 1'b1;
                        default: ;
                    endcase
                end
            end else begin
                rdata = mem[addr];
                if (addr == FAULT_ADDR) begin
                    if (FAULT_TYPE == 1) rdata[FAULT_BIT] = 1'b0;
                    if (FAULT_TYPE == 2) rdata[FAULT_BIT] = 1'b1;
                end
                dout <= rdata;
            end
        end
    end

endmodule
