`timescale 1ns / 1ps

module tb_ModmulUnit;
    localparam integer LANES = 128;
    localparam integer LOGQ = 32;
    localparam integer LATENCY = 6;
    localparam integer TEST_VECTORS = 100;

    localparam logic [31:0] Q_CONST = 32'd998244353;
    localparam logic [31:0] R_INV = 32'd232013824; // (2^32)^-1 mod Q_CONST

    reg clk = 1'b0;
    reg [LANES*LOGQ-1:0] a;
    reg [LANES*LOGQ-1:0] w;
    reg [31:0] q;
    wire [LANES*LOGQ-1:0] product;

    reg [LANES*LOGQ-1:0] exp_pipe [0:LATENCY-1];
    reg                  val_pipe [0:LATENCY-1];
    reg [LANES*LOGQ-1:0] exp_next;
    reg                  val_next;

    integer vec_idx;
    integer lane;
    integer stage;
    integer checks;
    integer errors;

    reg [31:0] ra;
    reg [31:0] rw;
    reg [31:0] got;
    reg [31:0] exp;

    ModmulUnit dut (
        .clk(clk),
        .a(a),
        .w(w),
        .q(q),
        .product(product)
    );

    always #5 clk = ~clk;

    function automatic [31:0] std_mult_ref(
        input [31:0] aa,
        input [31:0] bb
    );
        longint unsigned result;
        begin
            // Standard modular multiplication: (a * b) mod Q
            result = (longint'(aa) * longint'(bb)) % longint'(Q_CONST);
            std_mult_ref = result[31:0];
        end
    endfunction

    function automatic [31:0] mont_prescale(
        input [31:0] val
    );
        longint unsigned result;
        begin
            // Prescale: val * 2^32 mod Q (convert to Montgomery form)
            result = (longint'(val) * 64'h100000000) % longint'(Q_CONST);
            mont_prescale = result[31:0];
        end
    endfunction

    initial begin
        a = '0;
        w = '0;
        q = '0;
        exp_next = '0;
        val_next = 1'b0;
        checks = 0;
        errors = 0;

        for (stage = 0; stage < LATENCY; stage = stage + 1) begin
            exp_pipe[stage] = '0;
            val_pipe[stage] = 1'b0;
        end

        for (vec_idx = 0; vec_idx < TEST_VECTORS + LATENCY + 2; vec_idx = vec_idx + 1) begin
            // One startup bubble before feeding real vectors.
            if (vec_idx == 0) begin
                a = '0;
                w = '0;
                q = Q_CONST;
                exp_next = '0;
                val_next = 1'b0;
            end else if (vec_idx <= TEST_VECTORS) begin
                for (lane = 0; lane < LANES; lane = lane + 1) begin
                    ra = $urandom() % Q_CONST;
                    rw = $urandom() % Q_CONST;
                    a[lane*LOGQ +: LOGQ] = ra;
                    // Prescale twiddle factor w to Montgomery form
                    w[lane*LOGQ +: LOGQ] = mont_prescale(rw);
                    // Expected result: standard modular multiplication
                    exp_next[lane*LOGQ +: LOGQ] = std_mult_ref(ra, rw);
                end
                q = Q_CONST;
                val_next = 1'b1;
            end else begin
                a = '0;
                w = '0;
                q = Q_CONST;
                exp_next = '0;
                val_next = 1'b0;
            end

            @(posedge clk);

            if (val_pipe[LATENCY-1]) begin
                for (lane = 0; lane < LANES; lane = lane + 1) begin
                    got = product[lane*LOGQ +: LOGQ];
                    exp = exp_pipe[LATENCY-1][lane*LOGQ +: LOGQ];
                    checks = checks + 1;
                    if (got !== exp) begin
                        errors = errors + 1;
                        if (errors <= 10) begin
                            $display(
                                "Mismatch vec=%0d lane=%0d got=%0d exp=%0d",
                                vec_idx, lane, got, exp
                            );
                        end
                    end
                end
            end

            for (stage = LATENCY-1; stage > 0; stage = stage - 1) begin
                exp_pipe[stage] = exp_pipe[stage-1];
                val_pipe[stage] = val_pipe[stage-1];
            end
            exp_pipe[0] = exp_next;
            val_pipe[0] = val_next;
        end

        if (errors == 0) begin
            $display("PASS: checks=%0d errors=0", checks);
        end else begin
            $display("FAIL: checks=%0d errors=%0d", checks, errors);
        end

        $finish;
    end

endmodule
