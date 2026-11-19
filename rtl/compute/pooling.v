`timescale 1ns/1ps

//======================================================================
// MaxPool 1.1.1: N개의 유효 수신마다 signed 최대값 하나를 출력한다.
// 창/stride 주소는 외부가 결정한다. 첫 항부터 비교해 전부 음수인 창도 지원.
// enable=0은 2단계 우회. 활성 iteration=0은 입력 폐기/부분 창 초기화.
//======================================================================
module pooling #(
    parameter integer BITWIDTH = 16,
    parameter integer BITWIDTH_POOLING_ITERATION = 16
)(
    input  wire clk,
    input  wire nrst,
    input  wire enable,
    input  wire in_enable,
    input  wire [BITWIDTH_POOLING_ITERATION-1:0] iteration,
    input  wire signed [BITWIDTH-1:0] in_data,

    output reg out_enable,
    output reg signed [BITWIDTH-1:0] out_data
);
    reg signed [BITWIDTH-1:0] maximum;
    reg [BITWIDTH_POOLING_ITERATION-1:0] input_count;
    reg pending_enable;
    reg signed [BITWIDTH-1:0] pending_data;
    wire signed [BITWIDTH-1:0] next_maximum;
    // 첫 항에서는 이전 창의 maximum을 무시해야 음수 창도 올바르다.
    assign next_maximum = (input_count == 0 || in_data > maximum) ? in_data : maximum;
    always @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            maximum <= 0;
            input_count <= 0;
            pending_enable <= 0;
            pending_data <= 0;
            out_enable <= 0;
            out_data <= 0;
        end
        else begin
            // S1: 직전 클럭에 완성한 창 결과를 전달한다.
            out_enable <= pending_enable;
            if (pending_enable) begin
                out_data <= pending_data;
            end
            pending_enable <= 0;

            // S0: 입력 공백에서는 현재 창과 카운터를 유지한다.
            if (in_enable) begin
                if (!enable) begin
                    input_count <= 0;
                    maximum <= 0;
                    pending_enable <= 1;
                    pending_data <= in_data;
                end
                else if (iteration == 0) begin
                    input_count <= 0;
                    maximum <= 0;
                end
                else if (input_count == iteration - 1'b1) begin
                    pending_enable <= 1;
                    pending_data <= next_maximum;
                    input_count <= 0;
                    maximum <= 0;
                end
                else begin
                    maximum <= next_maximum;
                    input_count <= input_count + 1'b1;
                end
            end
        end
    end
endmodule
