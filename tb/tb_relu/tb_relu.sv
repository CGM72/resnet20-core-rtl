`timescale 1ns/1ps
// Independent relu.v verification; cycle-valid and signed expected values.
module tb_relu;
    localparam integer WORD_W=16, FRAC_W=10, UNIT_IDX=3;
    `include "unit_check.svh"
endmodule
