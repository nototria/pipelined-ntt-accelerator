module tb_top();
localparam LG_N = 4;
localparam N = 1<<LG_N;

integer i, j;

reg clk;
reg rst_n;

reg [32*N-1: 0] mtx [0 : N-1];
reg [LG_N-1: 0] cnt;
reg en;

TransposeUnit #(.LG_N(LG_N))
m_unit(
     .clk(clk)
    ,.rst_n(rst_n)
    ,.en(en)
    ,.in(mtx[cnt])
    ,.out()
    ,.out_valid()
);

initial begin
    for(i=0; i<N; i=i+1) begin
        for(j=0; j<N ;j=j+1) begin
            mtx[i][j*32 +: 32] = i*N+j;
        end
    end
    $dumpfile("test.vcd");
    $dumpvars(0, tb_top);
    clk = 0;
    rst_n = 0;
    cnt = 0;
    en = 1;
    # 5; clk = 1;
    # 5; clk = 0;
    # 5; clk = 1;
    rst_n = 1;
    repeat(N*N) # 5 clk = ~clk;
    $finish;
end

always @(posedge clk) begin
    if(~rst_n) cnt <= 0;
    else begin
        if(cnt == N-1) begin
            cnt <= 0;
            en <= 0;
        end
        else cnt <= cnt+1;
    end
end

endmodule
