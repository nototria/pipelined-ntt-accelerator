`timescale 1ns / 1ps

module PipelineNTT_top (
    input  wire          clk,
    input  wire          rst_n,
    input  wire          en,
    input  wire          inv,
    input  wire [31:0]   Q,
    input  wire          Q_we,
    input  wire [8191:0] psi_k,
    input  wire          psi_k_we,
    input  wire [4095:0] in,
    output wire [4095:0] out,
    output wire          out_valid
);
    integer i;
    localparam integer LANES = 128;
    localparam integer NTT_STAGES = 7;
    localparam integer BTF_LATENCY = 8; // MODADD(1) + INTMUL(1) + MODRED(6)
    localparam integer DIT_UNIT_LATENCY = NTT_STAGES * BTF_LATENCY; // 56 cycles (measured)
    localparam integer MULMOD_UNIT_LATENCY = 7; // standalone ModmulUnit latency
    localparam integer EN_DELAY_CYCLES = DIT_UNIT_LATENCY + MULMOD_UNIT_LATENCY;
    localparam [31:0] W_TEMP = 32'd301989884; // TODO (replace with SRAM twiddle later)

    reg [8191:0] psi_k_reg;
    reg [31:0] Q_reg;
    always @(posedge clk) begin
        if(Q_we) Q_reg <= Q;
        if(psi_k_we) psi_k_reg <= psi_k;
    end
    
    wire [32*LANES-1:0] dit_out;
    wire [32*LANES-1:0] mod_mul_out;
    wire [32*LANES-1:0] tr_out;
    wire tr_out_valid;

    // en alignment
    wire tr_en;
    reg [EN_DELAY_CYCLES-1:0] en_shift_reg;
    reg [DIT_UNIT_LATENCY-1: 0] out_valid_shift_reg;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            en_shift_reg <= {EN_DELAY_CYCLES{1'b0}};
            out_valid_shift_reg <= 0;
        end else begin
            en_shift_reg <= {en_shift_reg[EN_DELAY_CYCLES-2:0], en};
            out_valid_shift_reg <= {out_valid_shift_reg[DIT_UNIT_LATENCY-2:0], tr_out_valid};
        end
    end
    assign tr_en = en_shift_reg[EN_DELAY_CYCLES-1];
    assign out_valid = out_valid_shift_reg[DIT_UNIT_LATENCY-1];

    dit_ntt u_dit_ntt (
        .clk(clk),
        .inv(inv),
        .q(Q_reg),
        .psi_k(psi_k_reg),
        .in(in),
        .out(dit_out)
    );

    ModmulUnit u_mulmod_unit (
        .clk(clk),
        .a(dit_out),
        .w({LANES{W_TEMP}}),
        .q(Q_reg),
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

    // always @(posedge clk) begin
    //     if(1) begin
    //         for(i=0;i<128;i=i+1) $write("%d ", out[i*32 +:32]);
    //         $display();
    //     end
    // end

    dif_ntt u_dif_ntt (
        .clk(clk),
        .inv(inv),
        .q(Q_reg),
        .psi_k(psi_k_reg),
        .in(tr_out),
        .out(out)
    );

endmodule
