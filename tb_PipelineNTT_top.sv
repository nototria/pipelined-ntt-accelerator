`timescale 1ns / 1ps

module tb_PipelineNTT_top;

localparam int LANES = 128;
localparam int WIDTH = 32;
localparam int VECTOR_BITS = LANES * WIDTH;

localparam int NTT_STAGES = 7;
localparam int BTF_LATENCY = 8; // MODADD(1) + INTMUL(1) + MODRED(6)
localparam int DIT_UNIT_LATENCY = NTT_STAGES * BTF_LATENCY; // 56 cycles (measured)
localparam int MULMOD_UNIT_LATENCY = 7;
localparam int EN_DELAY_CYCLES = DIT_UNIT_LATENCY + MULMOD_UNIT_LATENCY;

localparam int RESET_CYCLES = 4;
localparam int WARMUP_CYCLES = 140;
localparam int LATENCY_OBS_CYCLES = EN_DELAY_CYCLES + 40;
localparam int MODE_SWITCH_SETTLE_CYCLES = DIT_UNIT_LATENCY + 12;
localparam int STREAM_TEST_CYCLES = 300;

localparam logic [31:0] Q_CONST = 32'd998244353;
localparam logic [31:0] W_TEMP = 32'd1111111;
localparam logic [31:0] R_INV = 32'd232013824; // (2^32)^-1 mod Q_CONST

logic clk;
logic rst_n;
logic en;
logic forward;
logic [VECTOR_BITS-1:0] in;
logic [8191:0] psi_k;
wire [VECTOR_BITS-1:0] out;

logic [EN_DELAY_CYCLES-1:0] en_ref_shift;
logic [VECTOR_BITS-1:0] dit_delay_pipe [0:MULMOD_UNIT_LATENCY-1];

wire expected_tr_en = en_ref_shift[EN_DELAY_CYCLES-1];

integer shift_idx;
integer err_cnt;
integer check_cnt;
integer psi_idx;

PipelineNTT_top dut (
    .clk(clk),
    .rst_n(rst_n),
    .en(en),
    .forward(forward),
    .Q(Q_CONST),
    .psi_k(psi_k),
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

function automatic [VECTOR_BITS-1:0] make_pattern_vec(input int unsigned seed);
    integer lane_idx;
    longint unsigned lane_word;
    logic [VECTOR_BITS-1:0] vec_out;
    begin
        vec_out = '0;
        for (lane_idx = 0; lane_idx < LANES; lane_idx = lane_idx + 1) begin
            lane_word = (longint'(seed) +
                         (longint'(lane_idx) * 97) +
                         longint'(lane_idx >> 1)) % longint'(Q_CONST);
            vec_out[lane_idx*WIDTH +: WIDTH] = lane_word[31:0];
        end
        make_pattern_vec = vec_out;
    end
endfunction

task automatic drive_cycle(
    input logic en_i,
    input logic forward_i,
    input logic [VECTOR_BITS-1:0] in_i
);
    begin
        @(negedge clk);
        en = en_i;
        forward = forward_i;
        in = in_i;
        @(posedge clk);
        #1;
    end
endtask

task automatic apply_reset_and_warmup(input logic forward_i);
    integer i;
    begin
        rst_n = 1'b0;
        en = 1'b0;
        forward = forward_i;
        in = '0;

        repeat (RESET_CYCLES) @(posedge clk);
        #1;
        rst_n = 1'b1;

        for (i = 0; i < WARMUP_CYCLES; i = i + 1) begin
            drive_cycle(1'b0, forward_i, '0);
        end
    end
endtask

task automatic run_mode_wiring_check;
    begin
        if ((dut.u_dit_ntt.q !== Q_CONST) || (dut.u_dif_ntt.q !== Q_CONST)) begin
            $display("[FAIL] q wiring mismatch. dit_q=%0d dif_q=%0d expected=%0d",
                     dut.u_dit_ntt.q, dut.u_dif_ntt.q, Q_CONST);
            $fatal(1);
        end

        if ((dut.u_dit_ntt.psi_k !== psi_k) || (dut.u_dif_ntt.psi_k !== psi_k)) begin
            $display("[FAIL] psi_k wiring mismatch between top and NTT submodules");
            $fatal(1);
        end

        drive_cycle(1'b0, 1'b1, '0);
        if ((dut.u_dit_ntt.inv !== 1'b0) || (dut.u_dif_ntt.inv !== 1'b0)) begin
            $display("[FAIL] inv wiring mismatch in forward mode. dit_inv=%b dif_inv=%b",
                     dut.u_dit_ntt.inv, dut.u_dif_ntt.inv);
            $fatal(1);
        end

        drive_cycle(1'b0, 1'b0, '0);
        if ((dut.u_dit_ntt.inv !== 1'b1) || (dut.u_dif_ntt.inv !== 1'b1)) begin
            $display("[FAIL] inv wiring mismatch in inverse mode. dit_inv=%b dif_inv=%b",
                     dut.u_dit_ntt.inv, dut.u_dif_ntt.inv);
            $fatal(1);
        end

        drive_cycle(1'b0, 1'b1, '0);
        $display("[PASS] forward/inverse wiring check passed");
    end
endtask

task automatic capture_dit_after_settle(
    input logic mode_forward,
    input logic [VECTOR_BITS-1:0] vec_in,
    output logic [VECTOR_BITS-1:0] dit_sample
);
    integer cyc;
    begin
        for (cyc = 0; cyc < MODE_SWITCH_SETTLE_CYCLES; cyc = cyc + 1) begin
            drive_cycle(1'b0, mode_forward, vec_in);
        end
        dit_sample = dut.dit_out;
    end
endtask

task automatic run_mode_functional_check;
    logic [VECTOR_BITS-1:0] pattern0;
    logic [VECTOR_BITS-1:0] pattern1;
    logic [VECTOR_BITS-1:0] dit_forward0;
    logic [VECTOR_BITS-1:0] dit_inverse0;
    logic [VECTOR_BITS-1:0] dit_forward1;
    logic [VECTOR_BITS-1:0] dit_inverse1;
    begin
        pattern0 = make_pattern_vec(32'd7);
        pattern1 = make_pattern_vec(32'd12345);

        capture_dit_after_settle(1'b1, pattern0, dit_forward0);
        capture_dit_after_settle(1'b0, pattern0, dit_inverse0);

        if (!is_known(dit_forward0) || !is_known(dit_inverse0)) begin
            $display("[FAIL] DIT output contains X/Z during mode functional check (pattern0)");
            $fatal(1);
        end
        if (dit_forward0 == dit_inverse0) begin
            $display("[FAIL] Forward/Inverse DIT outputs unexpectedly match for pattern0");
            $fatal(1);
        end

        capture_dit_after_settle(1'b1, pattern1, dit_forward1);
        capture_dit_after_settle(1'b0, pattern1, dit_inverse1);

        if (!is_known(dit_forward1) || !is_known(dit_inverse1)) begin
            $display("[FAIL] DIT output contains X/Z during mode functional check (pattern1)");
            $fatal(1);
        end
        if (dit_forward1 == dit_inverse1) begin
            $display("[FAIL] Forward/Inverse DIT outputs unexpectedly match for pattern1");
            $fatal(1);
        end

        $display("[PASS] forward/inverse functional check passed");
    end
endtask

task automatic run_latency_check;
    integer cyc;
    integer first_tr_en_idx;
    integer tr_en_latency_meas;
    logic [VECTOR_BITS-1:0] pulse_vec;
    begin
        first_tr_en_idx = -1;

        pulse_vec = '0;
        pulse_vec[0 +: WIDTH] = 32'd1;

        for (cyc = 0; cyc < LATENCY_OBS_CYCLES; cyc = cyc + 1) begin
            if (cyc == 0) begin
                drive_cycle(1'b1, 1'b1, pulse_vec);
            end else begin
                drive_cycle(1'b0, 1'b1, '0);
            end

            if ((first_tr_en_idx < 0) && (dut.tr_en === 1'b1)) begin
                first_tr_en_idx = cyc;
            end
        end

        if (first_tr_en_idx < 0) begin
            $display("[FAIL] latency detection failed: tr_en was never asserted");
            $fatal(1);
        end

        tr_en_latency_meas = first_tr_en_idx + 1;

        if (tr_en_latency_meas != EN_DELAY_CYCLES) begin
            $display("[FAIL] tr_en latency mismatch. expected=%0d measured=%0d",
                     EN_DELAY_CYCLES, tr_en_latency_meas);
            $fatal(1);
        end

        $display("[INFO] configured latency: DIT=%0d, ModMul=%0d, tr_en delay=%0d",
                 DIT_UNIT_LATENCY, MULMOD_UNIT_LATENCY, EN_DELAY_CYCLES);
        $display("[PASS] tr_en latency check passed");
    end
endtask

task automatic run_stream_integration_check;
    integer cyc;
    integer lane;
    logic rand_forward;
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

            rand_forward = $urandom_range(0, 1);
            drive_cycle(($urandom_range(0, 3) != 0), rand_forward, rand_vec);

            check_cnt = check_cnt + 1;

            if (dut.tr_en !== expected_tr_en) begin
                err_cnt = err_cnt + 1;
                if (err_cnt <= 10) begin
                    $display("[FAIL] tr_en mismatch at cyc=%0d expected=%b got=%b",
                             cyc, expected_tr_en, dut.tr_en);
                end
            end

            if (dut.u_dit_ntt.inv !== ~rand_forward) begin
                err_cnt = err_cnt + 1;
                if (err_cnt <= 10) begin
                    $display("[FAIL] DIT inv mismatch at cyc=%0d forward=%b dit_inv=%b",
                             cyc, rand_forward, dut.u_dit_ntt.inv);
                end
            end

            if (dut.u_dif_ntt.inv !== ~rand_forward) begin
                err_cnt = err_cnt + 1;
                if (err_cnt <= 10) begin
                    $display("[FAIL] DIF inv mismatch at cyc=%0d forward=%b dif_inv=%b",
                             cyc, rand_forward, dut.u_dif_ntt.inv);
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
    forward = 1'b1;
    in = '0;
    psi_k = '0;
    for (psi_idx = 0; psi_idx < 256; psi_idx = psi_idx + 1) begin
        psi_k[psi_idx*32 +: 32] = psi_idx + 1;
    end

    $dumpfile("pipeline_ntt_top_test.vcd");
    $dumpvars(0, tb_PipelineNTT_top);

    apply_reset_and_warmup(1'b1);
    run_mode_wiring_check();
    run_latency_check();

    // Re-warmup to clear transient data before mode functional checks.
    repeat (EN_DELAY_CYCLES + 20) begin
        drive_cycle(1'b0, 1'b1, '0);
    end

    run_mode_functional_check();

    // Re-warmup to clear transient data before randomized integration checks.
    repeat (EN_DELAY_CYCLES + 20) begin
        drive_cycle(1'b0, 1'b1, '0);
    end

    run_stream_integration_check();

    $display("[PASS] PipelineNTT_top testbench completed");
    $finish;
end

endmodule
