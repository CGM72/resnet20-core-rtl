`timescale 1ns/1ps

//======================================================================
// ReLU 1.1.1: enable=1이면 signed 음수를 0으로, 나머지는 그대로 전달한다.
// 두 단계의 데이터/valid 레지스터. bubble에서는 출력값을 유지한다.
//======================================================================
module relu #(
    parameter integer BITWIDTH = 16
)(
    input  wire clk,
    input  wire nrst,
    input  wire enable,
    input  wire in_enable,
    input  wire signed [BITWIDTH-1:0] in_data,

    output wire out_enable,
    output wire signed [BITWIDTH-1:0] out_data
);
    reg pending_enable;
    reg signed [BITWIDTH-1:0] pending_data;
    reg result_valid;
    reg signed [BITWIDTH-1:0] result_data;
    assign out_enable = result_valid;
    assign out_data = result_data;
    always @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            pending_enable <= 0;
            pending_data <= 0;
            result_valid <= 0;
            result_data <= 0;
        end
        else begin
            // 부호 비트 검사로 signed 비교를 단순화한다. 비활성 시 우회한다.
            pending_enable <= in_enable;
            if (in_enable) begin
                pending_data <= enable && in_data[BITWIDTH-1] ? 0 : in_data;
            end

            // S1: 선택한 값과 valid를 같은 지연으로 출력한다.
            result_valid <= pending_enable;
            if (pending_enable) begin
                result_data <= pending_data;
            end
        end
    end
endmodule
