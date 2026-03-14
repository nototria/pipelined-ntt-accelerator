`timescale 1ns / 1ps

`include "NTT-RTL-gen/rtl-gen/dif_ntt.v"
`include "NTT-RTL-gen/rtl-gen/dit_ntt.v"

module PipelineNTT_top (
    input  wire          clk,
    input  wire [4095:0] in,
    output wire [4095:0] out,
    output wire [4095:0] dit_out,
    output wire [4095:0] dif_out
);
    dif_ntt u_dif_ntt (
        .clk(clk),
        .in (in),
        .out(dif_out)
    );

    dit_ntt u_dit_ntt (
        .clk(clk),
        .in (in),
        .out(dit_out)
    );

`ifdef PIPELINE_NTT_USE_DIF
    assign out = dif_out;
`else
    assign out = dit_out;
`endif
endmodule
