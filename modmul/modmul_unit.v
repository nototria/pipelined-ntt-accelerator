`timescale 1ns / 1ps

// Fixed 128-lane packed 32-bit modular multiplier.
module modmul_unit (
    input  wire          clk,
    input  wire [4095:0] a,
    input  wire [4095:0] w,
    input  wire [31:0]   q,
    output wire [4095:0] product
);

    localparam integer LANES = 128;

    genvar i;
    generate
        for (i = 0; i < LANES; i = i + 1) begin : g_mul_lane
            multiply_unit u_mul (
                .clk(clk),
                .a(a[i*32 +: 32]),
                .b(w[i*32 +: 32]),
                .q(q),
                .c(product[i*32 +: 32])
            );
        end
    endgenerate

endmodule
