`timescale 1ns/1ps

//======================================================================
// mac 1.1.1: bias=0인 단독 MAC 포트. 기본 수치 형식은 Q5.10.
// core는 아래 mac_accumulate를 사용해 bias와 skip 경계도 함께 처리한다.
// 설정은 첫 입력 전부터 모든 결과 배출까지 고정한다. ready는 없다.
//======================================================================
module mac #(
    parameter integer BITWIDTH = 16,
    parameter integer BITWIDTH_MAC_ITERATION = 16,
    parameter integer FRAC_W = 10
)(
    input  wire clk,
    input  wire nrst,
    input  wire enable,
    input  wire in_enable,
    input  wire [BITWIDTH_MAC_ITERATION-1:0] iteration,
    input  wire signed [BITWIDTH-1:0] in_data,
    input  wire signed [BITWIDTH-1:0] kernel_data,

    output reg out_enable,
    output reg signed [BITWIDTH-1:0] out_data
);
    wire result_valid;
    wire signed [BITWIDTH-1:0] result_data;
    mac_accumulate #(
        .BITWIDTH(BITWIDTH),
        .BITWIDTH_MAC_ITERATION(BITWIDTH_MAC_ITERATION),
        .FRAC_W(FRAC_W)
    ) u_accumulate (
        .clk(clk),
        .nrst(nrst),
        .enable(enable),
        .iteration(iteration),
        .in_enable(in_enable),
        .in_data(in_data),
        .kernel_data(kernel_data),
        .bias_data({BITWIDTH{1'b0}}),
        .last_input(),
        .out_enable(result_valid),
        .out_data(result_data)
    );
    always @* begin
        out_enable = result_valid;
        out_data = result_data;
    end
endmodule

//======================================================================
// mac_accumulate 1.1.1: 한 입력/클럭, 5단계 단일 lane MAC.
// S0 곱셈 → S1 누산/최종 합 → S2 절댓값 → S3 반올림 → S4 포화/부호 복원.
// 첫 항 bias만 사용하며 N번째 항을 받은 E0의 결과는 E4 직후 유효하다.
// enable=0 우회도 같은 지연이다. iteration=0은 부분 그룹을 폐기한다.
// 데이터 레지스터는 reset하지 않고 valid만 reset해 DSP 레지스터 추론을 돕는다.
//======================================================================
module mac_accumulate #(
    parameter integer BITWIDTH = 16,
    parameter integer BITWIDTH_MAC_ITERATION = 16,
    parameter integer FRAC_W = 10
)(
    input wire clk, nrst, enable, in_enable,
    input wire [BITWIDTH_MAC_ITERATION-1:0] iteration,
    input wire signed [BITWIDTH-1:0] in_data, kernel_data, bias_data,
    output wire last_input,
    output reg out_enable,
    output reg signed [BITWIDTH-1:0] out_data
);
    // 수치 폭: 곱/누산은 Q(2*FRAC_W), 출력은 Q(FRAC_W).
    localparam integer WORD_W = BITWIDTH;
    localparam integer ITER_W = BITWIDTH_MAC_ITERATION;
    localparam integer PROD_W = 2 * WORD_W;
    localparam integer ACC_W = PROD_W + ITER_W;
    localparam integer MAG_W = ACC_W + 1;
    localparam [MAG_W-1:0] ONE = {{(MAG_W-1){1'b0}}, 1'b1};
    localparam [MAG_W-1:0] HALF = FRAC_W > 0 ? ONE << (FRAC_W-1) : 0;
    localparam [MAG_W-1:0] POS_LIMIT = (ONE << (WORD_W-1))-1'b1;
    localparam [MAG_W-1:0] NEG_LIMIT = ONE << (WORD_W-1);

    generate
        if (WORD_W < 2 || ITER_W < 1 || FRAC_W < 0 || FRAC_W >= WORD_W) begin : g_invalid
            MAC_REQUIRES_VALID_WIDTHS invalid_configuration();
        end
    endgenerate

    // 수신 카운터와 S0~S4 파이프라인. 신호명은 기존 파형 가이드와 동일하다.
    reg [ITER_W-1:0] input_count;
    reg s0_valid, s0_first, s0_last, s0_bypass;
    (* use_dsp = "yes" *) reg signed [PROD_W-1:0] s0_product;
    reg signed [WORD_W-1:0] s0_bias, s0_data;
    reg signed [ACC_W-1:0] accumulator, s1_sum;
    reg s1_valid;
    reg [MAG_W-1:0] s2_magnitude, s3_rounded;
    reg s2_negative, s3_negative, s2_valid, s3_valid;

    // 조합 경로: S0 입력 수신 조건, S1 누산의 피드백 값, S2 부호 확장.
    wire accepted = in_enable && (!enable || iteration != 0);
    wire signed [ACC_W-1:0] product_ext = {{(ACC_W-PROD_W){s0_product[PROD_W-1]}}, s0_product};
    wire signed [ACC_W-1:0] bias_ext = {{(ACC_W-WORD_W){s0_bias[WORD_W-1]}}, s0_bias};
    wire signed [ACC_W-1:0] bypass_ext = {{(ACC_W-WORD_W){s0_data[WORD_W-1]}}, s0_data};
    wire signed [ACC_W-1:0] total = (s0_first ? (bias_ext <<< FRAC_W) : accumulator) + product_ext;
    wire signed [MAG_W-1:0] extended_sum = {s1_sum[ACC_W-1], s1_sum};
    assign last_input = enable && in_enable && iteration != 0 && input_count == iteration - 1'b1;

    // 카운터와 valid만 취소하면 진행 중 데이터는 reset 뒤 출력되지 않는다.
    always @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            input_count <= 0;
            s0_valid <= 0;
            s1_valid <= 0;
            s2_valid <= 0;
            s3_valid <= 0;
            out_enable <= 0;
        end else begin
            s0_valid <= accepted;
            s1_valid <= s0_valid && (s0_bypass || s0_last);
            s2_valid <= s1_valid;
            s3_valid <= s2_valid;
            out_enable <= s3_valid;
            if (in_enable) begin
                if (!enable || iteration == 0 || last_input)
                    input_count <= 0;
                else
                    input_count <= input_count + 1'b1;
            end
        end
    end

    // S0: 곱셈과 그룹 경계를 함께 등록한다. 첫 항/마지막 항이 데이터와 이동한다.
    always @(posedge clk) begin
        if (accepted) begin
            s0_product <= in_data * kernel_data;
            s0_bias <= bias_data;
            s0_data <= in_data;
            s0_first <= input_count == 0;
            s0_last <= last_input;
            s0_bypass <= !enable;
        end

        // S1: 누산 피드백에는 덧셈만 남긴다. 새 그룹은 첫 항 bias로 시작한다.
        if (s0_valid) begin
            if (s0_bypass)
                s1_sum <= bypass_ext <<< FRAC_W;
            else begin
                accumulator <= total;
                if (s0_last)
                    s1_sum <= total;
            end
        end

        // S2: 최솟값도 안전하게 표현하도록 한 비트 확장 후 절댓값을 취한다.
        if (s1_valid) begin
            s2_negative <= extended_sum < 0;
            s2_magnitude <= extended_sum < 0 ? $unsigned(-extended_sum) : $unsigned(extended_sum);
        end

        // S3: 양/음 모두 정확한 절반은 0에서 먼 방향으로 반올림한다.
        if (s2_valid) begin
            s3_negative <= s2_negative;
            s3_rounded <= (s2_magnitude + HALF) >> FRAC_W;
        end

        // S4: magnitude 한계 비교 뒤 WORD_W 폭에서 부호를 복원한다.
        if (s3_valid) begin
            if (s3_negative)
                out_data <= s3_rounded > NEG_LIMIT
                    ? {1'b1, {(WORD_W-1){1'b0}}} : -$signed(s3_rounded[WORD_W-1:0]);
            else
                out_data <= s3_rounded > POS_LIMIT
                    ? {1'b0, {(WORD_W-1){1'b1}}} : $signed(s3_rounded[WORD_W-1:0]);
        end
    end
endmodule
