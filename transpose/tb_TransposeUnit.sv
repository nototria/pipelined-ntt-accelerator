module tb_TransposeUnit;
localparam int LG_N  = 4;
localparam int N     = 1 << LG_N;
localparam int WIDTH = 32;

localparam int MAX_FULL_MAT_CNT = 4;
localparam int MAX_TOTAL_MATS = MAX_FULL_MAT_CNT + 1;
localparam int MAX_TOTAL_INPUT_ROWS = MAX_FULL_MAT_CNT * N + (N - 1);
localparam int MAX_TOTAL_EXPECT_ROWS = MAX_TOTAL_MATS * N;
localparam int MAX_DRAIN_CYCLES = 12 * N;

localparam bit PRINT_ALL_EXPECTED = 1'b0;
localparam bit DRIVE_GARBAGE_WHEN_EN0 = 1'b1;

logic clk;
logic rst_n;
logic en;
logic [WIDTH*N-1:0] in;
wire  [WIDTH*N-1:0] out;
wire out_valid;

logic [WIDTH-1:0] matrix_data [0:MAX_TOTAL_MATS-1][0:N-1][0:N-1];
logic [WIDTH*N-1:0] input_rows [0:MAX_TOTAL_INPUT_ROWS-1];
logic [WIDTH*N-1:0] expected_rows [0:MAX_TOTAL_EXPECT_ROWS-1];

integer full_mat_cnt;
integer partial_rows;
integer total_mats;
integer total_input_rows;
integer total_expect_rows;

integer expected_idx;
integer mismatch_count;

TransposeUnit #(.LG_N(LG_N), .WIDTH(WIDTH)) dut (
     .clk(clk)
    ,.rst_n(rst_n)
    ,.en(en)
    ,.in(in)
    ,.out(out)
    ,.out_valid(out_valid)
);

function automatic logic [WIDTH*N-1:0] make_random_row;
    integer c;
    logic [WIDTH*N-1:0] row_vec;
    begin
        row_vec = '0;
        for (c = 0; c < N; c = c + 1) begin
            row_vec[c*WIDTH +: WIDTH] = $urandom;
        end
        make_random_row = row_vec;
    end
endfunction

task automatic build_test_vectors;
    integer m;
    integer r;
    integer c;
    integer idx;
    logic [WIDTH*N-1:0] row_vec;
    integer cfg_full;
    integer cfg_partial;
    begin
        full_mat_cnt = $urandom_range(1, MAX_FULL_MAT_CNT);
        partial_rows = $urandom_range(1, N-1);

        if ($value$plusargs("FULL_MAT_CNT=%d", cfg_full)) begin
            if (cfg_full < 1) cfg_full = 1;
            if (cfg_full > MAX_FULL_MAT_CNT) cfg_full = MAX_FULL_MAT_CNT;
            full_mat_cnt = cfg_full;
        end

        if ($value$plusargs("PARTIAL_ROWS=%d", cfg_partial)) begin
            if (cfg_partial < 0) cfg_partial = 0;
            if (cfg_partial > (N-1)) cfg_partial = N-1;
            partial_rows = cfg_partial;
        end

        total_mats = full_mat_cnt + ((partial_rows > 0) ? 1 : 0);

        for (m = 0; m < MAX_TOTAL_MATS; m = m + 1) begin
            for (r = 0; r < N; r = r + 1) begin
                for (c = 0; c < N; c = c + 1) begin
                    matrix_data[m][r][c] = '0;
                end
            end
        end

        for (m = 0; m < full_mat_cnt; m = m + 1) begin
            for (r = 0; r < N; r = r + 1) begin
                for (c = 0; c < N; c = c + 1) begin
                    matrix_data[m][r][c] = $urandom;
                end
            end
        end

        if (partial_rows > 0) begin
            for (r = 0; r < partial_rows; r = r + 1) begin
                for (c = 0; c < N; c = c + 1) begin
                    matrix_data[full_mat_cnt][r][c] = $urandom;
                end
            end
        end

        idx = 0;
        for (m = 0; m < full_mat_cnt; m = m + 1) begin
            for (r = 0; r < N; r = r + 1) begin
                row_vec = '0;
                for (c = 0; c < N; c = c + 1) begin
                    row_vec[c*WIDTH +: WIDTH] = matrix_data[m][r][c];
                end
                input_rows[idx] = row_vec;
                idx = idx + 1;
            end
        end

        if (partial_rows > 0) begin
            for (r = 0; r < partial_rows; r = r + 1) begin
                row_vec = '0;
                for (c = 0; c < N; c = c + 1) begin
                    row_vec[c*WIDTH +: WIDTH] = matrix_data[full_mat_cnt][r][c];
                end
                input_rows[idx] = row_vec;
                idx = idx + 1;
            end
        end
        total_input_rows = idx;

        idx = 0;
        for (m = 0; m < total_mats; m = m + 1) begin
            for (r = 0; r < N; r = r + 1) begin
                row_vec = '0;
                for (c = 0; c < N; c = c + 1) begin
                    row_vec[c*WIDTH +: WIDTH] = matrix_data[m][c][r];
                end
                expected_rows[idx] = row_vec;
                idx = idx + 1;
            end
        end
        total_expect_rows = idx;
    end
endtask

task automatic print_row(
    input string prefix,
    input logic [WIDTH*N-1:0] row_vec
);
    integer c;
    begin
        $write("%s", prefix);
        for (c = 0; c < N; c = c + 1) begin
            $write(" 0x%08X", row_vec[c*WIDTH +: WIDTH]);
        end
        $write("\n");
    end
endtask

task automatic print_expected_matrix(
    input int mat_idx
);
    integer r;
    integer c;
    integer base;
    begin
        base = mat_idx * N;
        $display("  expected matrix[%0d] (transposed output rows):", mat_idx);
        for (r = 0; r < N; r = r + 1) begin
            $write("    row[%0d]:", r);
            for (c = 0; c < N; c = c + 1) begin
                $write(" 0x%08X", expected_rows[base + r][c*WIDTH +: WIDTH]);
            end
            $write("\n");
        end
    end
endtask

task automatic print_all_expected_matrices;
    integer m;
    begin
        $display("========== FULL EXPECTED MATRICES ==========");
        for (m = 0; m < total_mats; m = m + 1) begin
            print_expected_matrix(m);
        end
        $display("===========================================");
    end
endtask

task automatic check_output;
    integer bad_mat_idx;
    begin
        if (out_valid) begin
            if (expected_idx >= total_expect_rows) begin
                mismatch_count = mismatch_count + 1;
                if (mismatch_count <= 5) begin
                    $display("[FAIL] Unexpected extra output row");
                    print_row("  out:", out);
                end
            end
            else begin
                if (out !== expected_rows[expected_idx]) begin
                    mismatch_count = mismatch_count + 1;
                    if (mismatch_count <= 5) begin
                        bad_mat_idx = expected_idx / N;
                        $display("[FAIL] Output row mismatch at idx=%0d", expected_idx);
                        print_row("  exp:", expected_rows[expected_idx]);
                        print_row("  out:", out);
                        print_expected_matrix(bad_mat_idx);
                    end
                end
                expected_idx = expected_idx + 1;
            end
        end
    end
endtask

task automatic drive_cycle(
    input logic valid,
    input logic [WIDTH*N-1:0] row_vec
);
    begin
        @(negedge clk);
        en = valid;
        in = row_vec;
        @(posedge clk);
        check_output();
    end
endtask

always #5 clk = ~clk;

initial begin
    integer i;
    integer drain_cycles;
    logic [WIDTH*N-1:0] invalid_row;

    build_test_vectors();

    $display("[TB] LG_N=%0d N=%0d full_mat_cnt=%0d partial_rows=%0d input_rows=%0d expect_rows=%0d",
             LG_N, N, full_mat_cnt, partial_rows, total_input_rows, total_expect_rows);

    if (PRINT_ALL_EXPECTED) begin
        print_all_expected_matrices();
    end

    clk = 1'b0;
    rst_n = 1'b0;
    en = 1'b0;
    in = '0;
    expected_idx = 0;
    mismatch_count = 0;

    $dumpfile("transpose_test.vcd");
    $dumpvars(0, tb_TransposeUnit);

    repeat (3) @(posedge clk);
    rst_n = 1'b1;

    for (i = 0; i < total_input_rows; i = i + 1) begin
        drive_cycle(1'b1, input_rows[i]);
    end

    drain_cycles = 0;
    while ((expected_idx < total_expect_rows) && (drain_cycles < MAX_DRAIN_CYCLES)) begin
        invalid_row = DRIVE_GARBAGE_WHEN_EN0 ? make_random_row() : '0;
        drive_cycle(1'b0, invalid_row);
        drain_cycles = drain_cycles + 1;
    end

    if (expected_idx != total_expect_rows) begin
        $display("[FAIL] Timeout waiting outputs: got %0d, expected %0d", expected_idx, total_expect_rows);
        $fatal(1);
    end

    repeat (4) begin
        invalid_row = DRIVE_GARBAGE_WHEN_EN0 ? make_random_row() : '0;
        drive_cycle(1'b0, invalid_row);
    end

    if (mismatch_count != 0) begin
        $display("[FAIL] Total mismatches: %0d", mismatch_count);
        $fatal(1);
    end

    $display("[PASS] TransposeUnit verified with random input: %0d full matrix/matrices + partial %0d/%0d rows. RTL padding path checked with en=0 %s.",
             full_mat_cnt, partial_rows, N,
             DRIVE_GARBAGE_WHEN_EN0 ? "garbage input" : "zero input");
    $finish;
end

endmodule
