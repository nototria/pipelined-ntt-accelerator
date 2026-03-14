`timescale 1ns / 1ps

// Simplified CSA-tree compatibility module.
// For this 32-bit WL Montgomery setup, TREE_DEPTH_I is 1 or 2.
module csa_tree_3to2 #
(
    parameter integer WORD_SIZE_I = 48,
    parameter integer TREE_DEPTH_I = 3,
    parameter integer WORD_SIZE_O = WORD_SIZE_I
)
(
    input  wire [WORD_SIZE_I-1:0] tree_i [TREE_DEPTH_I-1:0],
    output logic [WORD_SIZE_O-1:0] tree_o [1:0]
);

    generate
        if (TREE_DEPTH_I <= 1) begin : g_depth_le_1
            always @(*) begin
                if (TREE_DEPTH_I == 1) begin
                    if (WORD_SIZE_O >= WORD_SIZE_I)
                        tree_o[0] = {{(WORD_SIZE_O-WORD_SIZE_I){1'b0}}, tree_i[0]};
                    else
                        tree_o[0] = tree_i[0][WORD_SIZE_O-1:0];
                end else begin
                    tree_o[0] = {WORD_SIZE_O{1'b0}};
                end
                tree_o[1] = {WORD_SIZE_O{1'b0}};
            end
        end else begin : g_depth_ge_2
            always @(*) begin
                if (WORD_SIZE_O >= WORD_SIZE_I) begin
                    tree_o[0] = {{(WORD_SIZE_O-WORD_SIZE_I){1'b0}}, tree_i[0]};
                    tree_o[1] = {{(WORD_SIZE_O-WORD_SIZE_I){1'b0}}, tree_i[1]};
                end else begin
                    tree_o[0] = tree_i[0][WORD_SIZE_O-1:0];
                    tree_o[1] = tree_i[1][WORD_SIZE_O-1:0];
                end
            end
        end
    endgenerate

    initial begin
        if (TREE_DEPTH_I > 2)
            $error("csa_tree_3to2 simplified implementation supports TREE_DEPTH_I <= 2 only");
    end

endmodule
