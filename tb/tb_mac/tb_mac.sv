`timescale 1ns/1ps
// Independent mac.v verification; cycle-valid and signed expected values.
module tb_mac;
    localparam integer WORD_W=16, FRAC_W=10, UNIT_IDX=0;
    `include "unit_check.svh"
endmodule
