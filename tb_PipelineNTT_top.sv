`timescale 1ns / 1ps

module tb_PipelineNTT_top;

localparam int LANES = 128;
localparam int WIDTH = 32;
localparam int VECTOR_BITS = LANES * WIDTH;

localparam int DIT_UNIT_LATENCY = 7;
localparam int MULMOD_UNIT_LATENCY = 7;
localparam int EN_DELAY_CYCLES = DIT_UNIT_LATENCY + MULMOD_UNIT_LATENCY;

localparam int RESET_CYCLES = 4;
localparam int WARMUP_CYCLES = 140;
localparam int LATENCY_OBS_CYCLES = EN_DELAY_CYCLES + 40;
localparam int STREAM_TEST_CYCLES = 300;

localparam logic [31:0] Q_CONST = 32'd998244353;
localparam logic [31:0] W_TEMP = 32'd1111111;
localparam logic [31:0] R_INV = 32'd232013824; // (2^32)^-1 mod Q_CONST

logic clk;
logic rst_n;
logic en;
logic [VECTOR_BITS-1:0] in;
wire [VECTOR_BITS-1:0] out;

logic [EN_DELAY_CYCLES-1:0] en_ref_shift;
logic [VECTOR_BITS-1:0] dit_delay_pipe [0:MULMOD_UNIT_LATENCY-1];

wire expected_tr_en = en_ref_shift[EN_DELAY_CYCLES-1];

integer shift_idx;
integer err_cnt;
integer check_cnt;

PipelineNTT_top dut (
    .clk(clk),
    .rst_n(rst_n),
    .en(en),
    .Q(Q_CONST),
    .in(in),
    .out(out)
);

always #5 clk = ~clk;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        en_ref_shift <= '0;
        for (shift_idx = 0; shift_idx < MULMOD_UNIT_LATENCY; shift_idx = shift_idx + 1) begin
            dit_delay_pipe[shift_idx] <= '0;
        end
    end else begin
        en_ref_shift <= {en_ref_shift[EN_DELAY_CYCLES-2:0], en};
        dit_delay_pipe[0] <= dut.dit_out;
        for (shift_idx = 1; shift_idx < MULMOD_UNIT_LATENCY; shift_idx = shift_idx + 1) begin
            dit_delay_pipe[shift_idx] <= dit_delay_pipe[shift_idx-1];
        end
    end
end

function automatic bit is_known(input logic [VECTOR_BITS-1:0] vec);
    begin
        is_known = !$isunknown(vec);
    end
endfunction

function automatic [31:0] modmul_temp_ref(input logic [31:0] a_word);
    longint unsigned mult_mod_q;
    longint unsigned mont_out;
    begin
        // Top currently feeds a non-Montgomery temporary w constant.
        // MultiplyUnit outputs Montgomery-reduced product, so include R_INV.
        mult_mod_q = (longint'(a_word) * longint'(W_TEMP)) % longint'(Q_CONST);
        mont_out = (mult_mod_q * longint'(R_INV)) % longint'(Q_CONST);
        modmul_temp_ref = mont_out[31:0];
    end
endfunction

function automatic [VECTOR_BITS-1:0] map_modmul_temp(
    input logic [VECTOR_BITS-1:0] vec_in
);
    integer lane_idx;
    logic [VECTOR_BITS-1:0] vec_out;
    begin
        vec_out = '0;
        for (lane_idx = 0; lane_idx < LANES; lane_idx = lane_idx + 1) begin
            vec_out[lane_idx*WIDTH +: WIDTH] = modmul_temp_ref(vec_in[lane_idx*WIDTH +: WIDTH]);
        end
        map_modmul_temp = vec_out;
    end
endfunction

task automatic drive_cycle(
    input logic en_i,
    input logic [VECTOR_BITS-1:0] in_i
);
    begin
        @(negedge clk);
        en = en_i;
        in = in_i;
        @(posedge clk);
        #1;
    end
endtask

task automatic apply_reset_and_warmup;
    integer i;
    begin
        rst_n = 1'b0;
        en = 1'b0;
        in = '0;

        repeat (RESET_CYCLES) @(posedge clk);
        #1;
        rst_n = 1'b1;

        for (i = 0; i < WARMUP_CYCLES; i = i + 1) begin
            drive_cycle(1'b0, '0);
        end
    end
endtask

task automatic run_latency_check;
    integer cyc;
    integer first_dit_idx;
    integer first_modmul_idx;
    integer first_tr_en_idx;
    integer dit_latency_meas;
    integer modmul_latency_meas;
    integer tr_en_latency_meas;
    logic [VECTOR_BITS-1:0] pulse_vec;
    logic [VECTOR_BITS-1:0] expected_dit_vec;
    logic [VECTOR_BITS-1:0] expected_modmul_vec;
    begin
        first_dit_idx = -1;
        first_modmul_idx = -1;
        first_tr_en_idx = -1;

        pulse_vec = '0;
        pulse_vec[0 +: WIDTH] = 32'd1;
        expected_dit_vec = {LANES{32'd1}};
        expected_modmul_vec = map_modmul_temp(expected_dit_vec);

        for (cyc = 0; cyc < LATENCY_OBS_CYCLES; cyc = cyc + 1) begin
            if (cyc == 0) begin
                drive_cycle(1'b1, pulse_vec);
            end else begin
                drive_cycle(1'b0, '0);
            end

            if ((first_dit_idx < 0) && is_known(dut.dit_out) && (dut.dit_out === expected_dit_vec)) begin
                first_dit_idx = cyc;
            end
            if ((first_modmul_idx < 0) && is_known(dut.mod_mul_out) && (dut.mod_mul_out === expected_modmul_vec)) begin
                first_modmul_idx = cyc;
            end
            if ((first_tr_en_idx < 0) && (dut.tr_en === 1'b1)) begin
                first_tr_en_idx = cyc;
            end
        end

        if ((first_dit_idx < 0) || (first_modmul_idx < 0) || (first_tr_en_idx < 0)) begin
            $display("[FAIL] latency detection failed: dit=%0d modmul=%0d tr_en=%0d",
                     first_dit_idx, first_modmul_idx, first_tr_en_idx);
            $fatal(1);
        end

        dit_latency_meas = first_dit_idx + 1;
        modmul_latency_meas = first_modmul_idx + 1;
        tr_en_latency_meas = first_tr_en_idx + 1;

        $display("[INFO] measured latency: DIT=%0d, DIT+modmul=%0d, tr_en=%0d",
                 dit_latency_meas, modmul_latency_meas, tr_en_latency_meas);

        if (dit_latency_meas != DIT_UNIT_LATENCY) begin
            $display("[FAIL] DIT latency mismatch. expected=%0d measured=%0d",
                     DIT_UNIT_LATENCY, dit_latency_meas);
            $fatal(1);
        end

        if (modmul_latency_meas != EN_DELAY_CYCLES) begin
            $display("[FAIL] DIT+modmul latency mismatch. expected=%0d measured=%0d",
                     EN_DELAY_CYCLES, modmul_latency_meas);
            $fatal(1);
        end

        if (tr_en_latency_meas != EN_DELAY_CYCLES) begin
            $display("[FAIL] tr_en latency mismatch. expected=%0d measured=%0d",
                     EN_DELAY_CYCLES, tr_en_latency_meas);
            $fatal(1);
        end

        if (modmul_latency_meas != tr_en_latency_meas) begin
            $display("[FAIL] modmul output and tr_en are not aligned. modmul=%0d tr_en=%0d",
                     modmul_latency_meas, tr_en_latency_meas);
            $fatal(1);
        end

        $display("[PASS] exact latency alignment verified for DIT/modmul/tr_en");
    end
endtask

task automatic run_stream_integration_check;
    integer cyc;
    integer lane;
    logic [VECTOR_BITS-1:0] rand_vec;
    logic [VECTOR_BITS-1:0] expected_modmul_vec;
    begin
        err_cnt = 0;
        check_cnt = 0;

        for (cyc = 0; cyc < STREAM_TEST_CYCLES; cyc = cyc + 1) begin
            rand_vec = '0;
            for (lane = 0; lane < LANES; lane = lane + 1) begin
                rand_vec[lane*WIDTH +: WIDTH] = $urandom() % Q_CONST;
            end

            drive_cycle(($urandom_range(0, 3) != 0), rand_vec);

            check_cnt = check_cnt + 1;

            if (dut.tr_en !== expected_tr_en) begin
                err_cnt = err_cnt + 1;
                if (err_cnt <= 10) begin
                    $display("[FAIL] tr_en mismatch at cyc=%0d expected=%b got=%b",
                             cyc, expected_tr_en, dut.tr_en);
                end
            end

            if (is_known(dut.mod_mul_out) && is_known(dit_delay_pipe[MULMOD_UNIT_LATENCY-1])) begin
                expected_modmul_vec = map_modmul_temp(dit_delay_pipe[MULMOD_UNIT_LATENCY-1]);
                if (dut.mod_mul_out !== expected_modmul_vec) begin
                    err_cnt = err_cnt + 1;
                    if (err_cnt <= 10) begin
                        $display("[FAIL] modmul_out mismatch at cyc=%0d", cyc);
                    end
                end
            end

            if ((dut.tr_out_valid === 1'b1) && !is_known(dut.tr_out)) begin
                err_cnt = err_cnt + 1;
                if (err_cnt <= 10) begin
                    $display("[FAIL] tr_out has unknown bits while out_valid=1 at cyc=%0d", cyc);
                end
            end
        end

        if (err_cnt != 0) begin
            $display("[FAIL] stream integration check errors=%0d checks=%0d", err_cnt, check_cnt);
            $fatal(1);
        end

        $display("[PASS] stream integration check passed (%0d cycles)", check_cnt);
    end
endtask

initial begin
    clk = 1'b0;
    rst_n = 1'b0;
    en = 1'b0;
    in = '0;

    $dumpfile("pipeline_ntt_top_test.vcd");
    $dumpvars(0, tb_PipelineNTT_top);

    apply_reset_and_warmup();
    run_latency_check();

    // Re-warmup to clear transient data before randomized integration checks.
    repeat (EN_DELAY_CYCLES + 20) begin
        drive_cycle(1'b0, '0);
    end

    run_stream_integration_check();

    $display("[PASS] PipelineNTT_top testbench completed");
    $finish;
end

endmodule
