/*
    OpenNTT - 2024
    Florian Krieger, Florian Hirner, Ahmet Can Mert, Sujoy Sinha Roy
    Contact: florian.krieger@iaik.tugraz.at
*/
`timescale 1ns/1ps

module MultiplyUnit #
(
    parameter LOGQ = 32,
    parameter [LOGQ-1:0] Q_VALUE = 0, // != 0: q is constant
    parameter WORD_SIZE = 16, // Last WORD_SIZE digit of q will be 00...001
    // integer multiplier parameters
    parameter INTMUL_LAT = 1, // should be at least 1 (valid only if INTMUL_TYPE="")
    parameter INTMUL_TYPE = "", // options: "", "fpga_auto", "fpga_lut", "fpga_dsp", "custom" (could be fpga IP, fpga-optimized, asic-optimized (i.e., Karatsuba) etc.)
    // modular reduction parameters
    parameter MODRED_LAT = 6, 
	  parameter MODRED_TYPE = "default", // options: "default" (WL Montgomery), "custom", "" (i.e., for sim)
	  // modular reduction parameters (for default case)
	  parameter MODRED_L = 2,  // montgomery loop count (calculated as $ceil(LOGQ/WORD_SIZE))
    parameter MODRED_COREMUL_LAT = 1 // latency of multiply and add units in WL Montgomery	
)
(
    input  clk,
    input  [LOGQ-1:0] q,
    input  [LOGQ-1:0] a,b,
    output [LOGQ-1:0] c
);

wire [2*LOGQ-1:0] imul;

// modmul
intmul #(LOGQ,LOGQ,INTMUL_LAT,INTMUL_TYPE) intmul_i(clk,b,a,imul);
modred #(LOGQ,Q_VALUE,WORD_SIZE,MODRED_LAT,MODRED_TYPE,MODRED_L,MODRED_COREMUL_LAT) modred_i(clk,imul,q,c);

endmodule
