`timescale 1ns/1ps
//======================================================================
// core 1.2.2: valid-only 단일 lane, 5개 연산 블록을 순서대로 연결한다.
// 내부 레지스터는 MAC 5 + Residual 2 + ReLU 2 + Pool 2 + GAP 4 = 15단이다.
// MAC → Residual → ReLU → MaxPool → GAP. 각 단계는 비활성 시 우회한다.
// 설정은 입력 시작 전부터 전체 pipeline이 비워질 때까지 유지해야 한다.
// residual 활성: MAC N항 다음 유효 in_data 하나가 skip이며 MAC에 넣지 않는다.
// ready 포트가 없으므로 출력은 out_enable=1인 매 클럭 반드시 수신한다.
// 레이어/주소/패딩/메모리/Controller는 이 모듈에 포함하지 않는다.
//======================================================================
module core #(
    // 데이터 폭 및 블록별 반복 횟수 포트 폭
    parameter integer BITWIDTH = 16,
    parameter integer BITWIDTH_MAC_ITERATION = 16,
    parameter integer BITWIDTH_POOLING_ITERATION = 16,
    parameter integer BITWIDTH_GAP_ITERATION = 16,
    // 현재 포트는 단일 lane이다. PARALLEL_PC/PF는 1만 지원한다.
    parameter integer PARALLEL_PC = 1,
    parameter integer PARALLEL_PF = 1,
    parameter integer FRAC_W = 10,
    parameter integer MAX_GAP_ITERATION = 1024
)(
    input wire clk,
    input wire nrst,

    // 블록 설정: 첫 입력 전부터 모든 결과 배출까지 고정
    input wire mac_enable,
    input wire [BITWIDTH_MAC_ITERATION-1:0] mac_iteration,
    input wire residual_enable,
    input wire relu_enable,
    input wire pooling_enable,
    input wire [BITWIDTH_POOLING_ITERATION-1:0] pooling_iteration,
    input wire gap_enable,
    input wire [BITWIDTH_GAP_ITERATION-1:0] gap_iteration,

    // 입력: in_enable=1인 상승 에지마다 한 항 수신
    input wire in_enable,
    input wire [BITWIDTH-1:0] in_data,
    input wire [BITWIDTH-1:0] kernel_data,
    input wire [BITWIDTH-1:0] bias_data,

    // 출력: out_enable=1인 매 상승 에지에 반드시 수신
    output reg out_enable,
    output reg [BITWIDTH-1:0] out_data
);

    //==================================================================
    // 포트 폭은 첨부처럼 scalar이다. 병렬화는 버스 규약을 합의한 뒤 확장한다.
    // 잘못된 병렬 파라미터를 조용히 무시하지 않고 elaboration을 실패시킨다.
    //==================================================================
    generate
        if (PARALLEL_PC != 1 || PARALLEL_PF != 1 || FRAC_W < 0 || FRAC_W >= BITWIDTH) begin : g_invalid
            CORE_REQUIRES_SINGLE_LANE_AND_VALID_FRAC_W invalid_configuration();
        end
    endgenerate

    wire use_residual = mac_enable && residual_enable;
    wire residual_in_valid, residual_valid, relu_valid, pooling_valid, gap_valid;
    wire signed [BITWIDTH-1:0] residual_main, residual_skip;
    wire signed [BITWIDTH-1:0] residual_data, relu_data, pooling_data, gap_data;

    // 1) Convolution: stream the taps and align the result with its skip.
    conv #(
        .BITWIDTH(BITWIDTH),
        .BITWIDTH_MAC_ITERATION(BITWIDTH_MAC_ITERATION),
        .FRAC_W(FRAC_W)
    ) u_conv (
        .clk(clk),
        .nrst(nrst),
        .mac_enable(mac_enable),
        .mac_iteration(mac_iteration),
        .use_residual(use_residual),
        .in_enable(in_enable),
        .in_data(in_data),
        .kernel_data(kernel_data),
        .bias_data(bias_data),
        .residual_in_valid(residual_in_valid),
        .residual_main(residual_main),
        .residual_skip(residual_skip)
    );

    // 2) Residual: 정렬된 main/skip의 포화 합.
    residual #(.BITWIDTH(BITWIDTH)) u_residual (
        .clk(clk),
        .nrst(nrst),
        .enable(use_residual),
        .in_enable(residual_in_valid),
        .in_data(residual_main),
        .skip_data(residual_skip),
        .out_enable(residual_valid),
        .out_data(residual_data)
    );

    // 3) ReLU: 음수 제거 또는 우회.
    relu #(.BITWIDTH(BITWIDTH)) u_relu (
        .clk(clk),
        .nrst(nrst),
        .enable(relu_enable),
        .in_enable(residual_valid),
        .in_data(residual_data),
        .out_enable(relu_valid),
        .out_data(relu_data)
    );

    // 4) MaxPool: 같은 창의 유효 결과 N개를 모아 최대값 생성.
    pooling #(
        .BITWIDTH(BITWIDTH),
        .BITWIDTH_POOLING_ITERATION(BITWIDTH_POOLING_ITERATION)
    ) u_pooling (
        .clk(clk),
        .nrst(nrst),
        .enable(pooling_enable),
        .iteration(pooling_iteration),
        .in_enable(relu_valid),
        .in_data(relu_data),
        .out_enable(pooling_valid),
        .out_data(pooling_data)
    );

    // 5) GAP: 같은 채널의 공간 결과 N개를 모아 평균 생성.
    general_average_pooling #(
        .BITWIDTH(BITWIDTH),
        .BITWIDTH_GAP_ITERATION(BITWIDTH_GAP_ITERATION),
        .MAX_GAP_ITERATION(MAX_GAP_ITERATION)
    ) u_gap (
        .clk(clk),
        .nrst(nrst),
        .enable(gap_enable),
        .iteration(gap_iteration),
        .in_enable(pooling_valid),
        .in_data(pooling_data),
        .out_enable(gap_valid),
        .out_data(gap_data)
    );
    always @* begin
        out_enable = gap_valid;
        out_data = gap_data;
    end

endmodule
