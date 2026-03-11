`timescale 1ns / 1ps

// Default: DIT core.
// Compile with -DPIPELINE_NTT_USE_DIF to switch to the DIF core.
`ifdef PIPELINE_NTT_USE_DIF
`include "NTT-RTL-gen/rtl-gen/dif_ntt.v"
`else
`include "NTT-RTL-gen/rtl-gen/dit_ntt.v"
`endif

module PipelineNTT_top (
    input  wire        clk,
    input  wire [4095:0] in,
    output wire [4095:0] out
);
    ntt u_ntt (
        .clk(clk),
        .in (in),
        .out(out)
    );
endmodule
