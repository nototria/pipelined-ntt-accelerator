`timescale 1ns / 1ps
`include "numbers.vh"

module tb_PipelineNTT_top;
integer i, j;

// system reg
reg clk, rst_n, en;
reg [3:0] trig_cnt;
reg done_reg;

// matrix
reg [32*128-1 :0] mtx [0: 127];
reg [31:0] cnt;

// ntt module
reg inv;
wire out_valid;
wire [32*128-1: 0] out;

always #5 clk=~clk;

initial begin
    // $dumpfile("tb_top.vcd");
    // $dumpvars(0, tb_PipelineNTT_top);
    inv = $test$plusargs("inv");
    $readmemh("/tmp/tmp.hex", mtx);
    clk = 0;
    rst_n = 0;
    done_reg = 0;
    trig_cnt = 0;
    en = 0;
end

always @(posedge clk) begin
    if(out_valid) done_reg <= 1;
    if(done_reg && !out_valid) $finish;
end

always @(posedge clk) begin
    if(out_valid) begin
        // output
        for(i=0; i<128; i=i+1) $write("%d ", out[i*32 +: 32]);
        $display();
    end
end

always @(posedge clk) begin
    if(~rst_n) cnt <= 0;
    else begin
        if(cnt == 128-1) en <= 0;
        else if(en) cnt <= cnt+1;
    end
end

always @(posedge clk) begin
    if(trig_cnt!=4'b1111) trig_cnt <= trig_cnt+1;
    if(trig_cnt==4'b0011) rst_n <= 1;
    if(trig_cnt==4'b0111) en <= 1;
end

PipelineNTT_top m_unit(
    .clk(clk),
    .rst_n(rst_n),
    .en(en),
    .inv(inv),
    .Q(`Q_CONST),
    .psi_k(`PSI_K_128),
    .in(mtx[cnt]),
    .out(out),
    .out_valid(out_valid)
);

endmodule
