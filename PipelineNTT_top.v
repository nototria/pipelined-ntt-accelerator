`timescale 1ns / 1ps

module PipelineNTT_top (
    input  wire          clk,
    input  wire          rst_n,
    input  wire          en,
    // input  wire       forward, TODO: support forward/inverse NTT selection
    input  wire [31:0]   Q,
    input  wire [4095:0] in,
    output wire [4095:0] out
);
    localparam integer LANES = 128;
    localparam integer DIT_UNIT_LATENCY = 7;
    localparam integer MULMOD_UNIT_LATENCY = 7;
    localparam integer EN_DELAY_CYCLES = DIT_UNIT_LATENCY + MULMOD_UNIT_LATENCY;
    localparam [31:0] W_TEMP = 32'd1111111; // TODO (replace with SRAM twiddle later)

    wire [32*LANES-1:0] dit_out;
    wire [32*LANES-1:0] mod_mul_out;
    wire [32*LANES-1:0] tr_out;
    wire tr_out_valid;

    // en alignment
    wire tr_en;
    reg [EN_DELAY_CYCLES-1:0] en_shift_reg;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            en_shift_reg <= {EN_DELAY_CYCLES{1'b0}};
        end else begin
            en_shift_reg <= {en_shift_reg[EN_DELAY_CYCLES-2:0], en};
        end
    end
    assign tr_en = en_shift_reg[EN_DELAY_CYCLES-1];

    dit_ntt u_dit_ntt (
        .clk(clk),
        .in(in),
        .out(dit_out)
    );

    ModmulUnit u_mulmod_unit (
        .clk(clk),
        .a(dit_out),
        .w({LANES{W_TEMP}}),
        .q(Q),
        .product(mod_mul_out)
    );

    TransposeUnit #(.LG_N(7)) m_tr_unit (
        .clk(clk),
        .rst_n(rst_n),
        .en(tr_en),
        .in(mod_mul_out),
        .out(tr_out),
        .out_valid(tr_out_valid)
    );

    dif_ntt u_dif_ntt (
        .clk(clk),
        .in(tr_out),
        .out(out)
    );

endmodule
