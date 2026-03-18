module QuadrantSwap
#(parameter LG_N = 1, parameter WIDTH=32, parameter N=1<<LG_N)
(
     input clk
    ,input rst_n
    ,input en
    ,input [WIDTH*N-1: 0] in
    ,output [WIDTH*N-1: 0] out
);
parameter half_N = 1<<(LG_N-1);
parameter IDX_bit = LG_N>1? LG_N-1: 1;

// state
reg state;
reg [IDX_bit-1: 0] buffer_idx;

// swap1
wire [WIDTH*half_N-1: 0] swap1_top, swap1_bottom;

// buffer
reg [WIDTH*half_N-1: 0] top_buffer [0: half_N-1];
reg [WIDTH*half_N-1: 0] bottom_buffer [0: half_N-1];

// mux
wire [WIDTH*half_N-1: 0] mux_out;

// swap2
wire [WIDTH*half_N-1: 0] swap2_top, swap2_bottom;

// =============================
// Logics
// =============================

// state and buffer_idx
always @(posedge clk) if(~rst_n) begin
    state <= 0;
    buffer_idx <= 0;
end
else if(en) begin
    if(buffer_idx+1 == half_N) begin
        state <= ~state;
        buffer_idx <= 0;
    end
    else buffer_idx <= buffer_idx+1;
end

// swap1
assign swap1_top    = state ? in[half_N*WIDTH +:half_N*WIDTH]: in[0 +:half_N*WIDTH];
assign swap1_bottom = state ? in[0 +:half_N*WIDTH]: in[half_N*WIDTH +:half_N*WIDTH];

// buffer
always @(posedge clk) begin
    top_buffer[buffer_idx] <= swap1_top;
    if(!state) bottom_buffer[buffer_idx] <= swap1_bottom;
end

// mux
assign mux_out = state? swap1_bottom: bottom_buffer[buffer_idx];

// swap2
assign swap2_top    = state? top_buffer[buffer_idx]: mux_out;
assign swap2_bottom = state? mux_out: top_buffer[buffer_idx];

// output
assign out = {swap2_bottom, swap2_top};

endmodule
/*
A B
C D

1. 
top: A
bottom: C

output: 

2. 
top: D
bottom: C

output: A, B

3. 
top: A'
bottom: C'

output C, D
*/
