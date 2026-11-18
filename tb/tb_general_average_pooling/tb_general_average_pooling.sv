`timescale 1ns/1ps
// Independent general_average_pooling.v verification; cycle-valid and signed expected values.
module tb_general_average_pooling;
    localparam integer WORD_W=16, FRAC_W=10, UNIT_IDX=5;
    `include "unit_check.svh"
endmodule
