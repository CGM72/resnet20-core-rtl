`timescale 1ns/1ps
// Independent residual.v verification; cycle-valid and signed expected values.
module tb_residual;
    localparam integer WORD_W=16, FRAC_W=10, UNIT_IDX=2;
    `include "unit_check.svh"
endmodule
