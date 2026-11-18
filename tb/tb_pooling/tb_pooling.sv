`timescale 1ns/1ps
// Independent pooling.v verification; cycle-valid and signed expected values.
module tb_pooling;
    localparam integer WORD_W=16, FRAC_W=10, UNIT_IDX=4;
    `include "unit_check.svh"
endmodule
