`timescale 1ns / 1ps

// Fixed single-lane 32-bit modular multiplier using WL Montgomery reduction.
module multiply_unit (
    input  wire        clk,
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [31:0] q,
    output wire [31:0] c
);

    localparam integer LOGQ = 32;
    localparam integer WORD_SIZE = 16;
    localparam integer INTMUL_LAT = 1;
    localparam integer MODRED_L = $ceil(LOGQ/WORD_SIZE);
    localparam integer MODRED_COREMUL_LAT = 1;
    localparam integer MODRED_LAT = 0;

    wire [63:0] mul_wide;

    intmul #
    (
        .LOG_A(32),
        .LOG_B(32),
        .INTMUL_LAT(INTMUL_LAT),
        .INTMUL_TYPE("")
    )
    u_intmul
    (
        .clk(clk),
        .A(a),
        .B(b),
        .C(mul_wide)
    );

    // Output is in WL/Montgomery domain:
    // c = a*b*R^-1 (mod q)
    modred #
    (
        .LOGQ(LOGQ),
        .Q_VALUE(32'd0),
        .WORD_SIZE(WORD_SIZE),
        .MODRED_LAT(MODRED_LAT),
        .MODRED_TYPE("default"),
        .MODRED_L(MODRED_L),
        .MODRED_COREMUL_LAT(MODRED_COREMUL_LAT)
    )
    u_modred
    (
        .clk(clk),
        .P(mul_wide),
        .q(q),
        .C(c)
    );

endmodule
