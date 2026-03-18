module TransposeUnit#(parameter LG_N = 1, parameter WIDTH=32, parameter N=1<<LG_N)
(
     input clk
    ,input rst_n
    ,input en
    ,input [WIDTH*N-1: 0] in
    ,output [WIDTH*N-1: 0] out
    ,output out_valid
);
integer j;
genvar i,k;
wire [WIDTH*N-1: 0] conn [0: LG_N];
wire flush_unit_en [0: LG_N-1];

// enable shift register
wire en_shift_reg_in [0: LG_N-1]; // also enable unit[i]
wire en_shift_reg_out [0: LG_N-1];

// fsm
reg [LG_N-1: 0] cnt; // for end padding
reg [1:0] fsm_state, nx_state;
localparam S_IDLE = 2'd0, S_RUN = 2'd1, S_PADDING = 2'd2, S_FLUSH = 2'd3;

// =============================
// Logics
// =============================

// enable shift register
generate
for(i=0; i<LG_N; i=i+1) begin
    reg en_shift_reg [0: (1<<(LG_N-1-i))-1];
    always @(posedge clk) begin
        if(!rst_n) begin
            for(j=0; j<(1<<(LG_N-1-i)); j=j+1) en_shift_reg[j] <= 1'b0;
        end
        else begin
            en_shift_reg[0] <= en_shift_reg_in[i];
            for(j=1; j<(1<<(LG_N-1-i)); j=j+1)
                en_shift_reg[j] <= en_shift_reg[j-1];
        end
    end
    assign en_shift_reg_out[i] = en_shift_reg[(1<<(LG_N-1-i)) -1];
end
endgenerate

assign en_shift_reg_in[0] = (
    (en & nx_state==S_RUN) | 
    nx_state==S_PADDING
);
generate
for(i=1; i<LG_N; i=i+1) begin
    assign en_shift_reg_in[i] = en_shift_reg_out[i-1];
end
endgenerate
assign out_valid = en_shift_reg_out[LG_N-1];

// QuadrantSwap Units
generate
for(i=0; i<LG_N; i=i+1) for(k=0;k<(1<<i); k=k+1)
    QuadrantSwap #(.LG_N(LG_N-i),.WIDTH(WIDTH)) m_unit(
         .clk(clk)
        ,.rst_n(rst_n)
        ,.en(en_shift_reg_in[i] | flush_unit_en[i])
        ,.in(conn[i][k*(1<<(LG_N-i))*WIDTH +: (1<<(LG_N-i))*WIDTH])
        ,.out(conn[i+1][k*(1<<(LG_N-i))*WIDTH +: (1<<(LG_N-i))*WIDTH])
    );
endgenerate
assign conn[0] = in;
assign out = conn[LG_N];

// fsm logic
always @(*) case (fsm_state)
    S_IDLE: nx_state = en ? S_RUN: S_IDLE;
    S_RUN: begin
        if(en) nx_state = S_RUN;
        else nx_state = cnt==0? S_FLUSH: S_PADDING;
    end
    S_PADDING: nx_state = cnt==0? S_FLUSH: S_PADDING;
    S_FLUSH: begin
        if(out_valid) nx_state = S_FLUSH;
        else nx_state = en? S_RUN: S_IDLE;
    end
endcase
always @(posedge clk) begin
    if(~rst_n) fsm_state <= S_IDLE;
    else fsm_state <= nx_state;
end

// cnt
// increase when running or end padding
always @(posedge clk) begin
    if(~rst_n) cnt <= 0;
    else begin
        if(
            nx_state==S_RUN || 
            nx_state==S_PADDING
        ) cnt <= cnt+1;
        else if(fsm_state==S_FLUSH && nx_state!=S_FLUSH) cnt <= 0;
    end
end

// flush unit en
generate
for(i=0; i<LG_N; i=i+1) assign flush_unit_en[i] = en_shift_reg_out[i];
endgenerate

endmodule
