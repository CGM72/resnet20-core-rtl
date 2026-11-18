`timescale 1ns/1ps
//======================================================================
// GAP v1.1.0: N은 1..MAX_GAP_ITERATION 범위의 2의 거듭제곱만 지원한다.
// 기본 지원 N=1,2,4,8,16,32,64,128,256,512,1024. 나눗셈 회로는 없다.
// S0 합 수집 → S1 절댓값 → S2 반올림/shift → S3 부호 복원.
// N번째 입력 E0 → 출력 E3. 우회도 같은 지연, 한 입력/클럭을 수신한다.
// 활성 상태에서 0/비지원 N은 입력을 버리고 부분 그룹을 초기화한다.
//======================================================================
module general_average_pooling #(
    parameter integer BITWIDTH = 16,
    parameter integer BITWIDTH_GAP_ITERATION = 16,
    parameter integer MAX_GAP_ITERATION = 1024
)(
    input wire clk, nrst, enable, in_enable,
    input wire [BITWIDTH_GAP_ITERATION-1:0] iteration,
    input wire signed [BITWIDTH-1:0] in_data,
    output reg out_enable,
    output reg signed [BITWIDTH-1:0] out_data
);
    localparam integer WORD_W=BITWIDTH;
    localparam integer ITER_W=BITWIDTH_GAP_ITERATION;
    localparam integer MAX_LOG=$clog2(MAX_GAP_ITERATION);
    localparam integer COUNT_W=MAX_LOG>0 ? MAX_LOG : 1;
    localparam integer SHIFT_W=MAX_LOG>0 ? $clog2(MAX_LOG+1) : 1;
    localparam integer SUM_W=WORD_W+MAX_LOG;
    localparam integer MAG_W=SUM_W+1;
    localparam [MAG_W-1:0] ONE={{(MAG_W-1){1'b0}},1'b1};
    localparam [ITER_W-1:0] ITER_ONE={{(ITER_W-1){1'b0}},1'b1};
    generate
        if (WORD_W<2 || MAX_GAP_ITERATION<1 ||
            (MAX_GAP_ITERATION & (MAX_GAP_ITERATION-1))!=0 || MAX_LOG>=ITER_W) begin : g_invalid
            GAP_REQUIRES_POWER_OF_TWO_MAX_WITHIN_ITERATION_WIDTH invalid_configuration();
        end
    endgenerate
    localparam [ITER_W-1:0] MAX_ITER=ITER_ONE<<MAX_LOG;
    wire supported = iteration!=0 && iteration<=MAX_ITER &&
                     (iteration & (iteration-1'b1))==0;
    reg [SHIFT_W-1:0] input_shift;
    integer bit_index;
    // one-hot N을 log2(N)으로 인코딩한다. 설정은 전체 작업 동안 고정한다.
    always @* begin
        input_shift=0;
        for (bit_index=0; bit_index<=MAX_LOG; bit_index=bit_index+1)
            if (iteration==(ITER_ONE<<bit_index)) input_shift=bit_index[SHIFT_W-1:0];
    end
    reg [COUNT_W-1:0] input_count;
    reg signed [SUM_W-1:0] accumulator, s0_sum;
    reg [SHIFT_W-1:0] s0_shift, s1_shift;
    reg [MAG_W-1:0] s1_magnitude;
    reg [WORD_W-1:0] s2_rounded;
    reg s0_valid,s1_valid,s2_valid,s1_negative,s2_negative;
    wire signed [SUM_W-1:0] input_ext={{(SUM_W-WORD_W){in_data[WORD_W-1]}},in_data};
    wire signed [SUM_W-1:0] total=accumulator+input_ext;
    wire last_input=in_enable && enable && supported && {{(ITER_W-COUNT_W){1'b0}},input_count}==iteration-1'b1;
    wire signed [MAG_W-1:0] extended_sum={s0_sum[SUM_W-1],s0_sum};
    wire [MAG_W-1:0] half=s1_shift==0 ? 0 : ONE<<(s1_shift-1'b1);
    wire [MAG_W-1:0] rounded_magnitude=(s1_magnitude+half)>>s1_shift;

    // 제어만 reset한다. 이전 데이터는 valid=0이므로 수신되지 않는다.
    // 첫 항은 accumulator 대신 input_ext로 시작하므로 데이터 reset이 필요 없다.
    always @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            input_count<=0;
            s0_valid<=0; s1_valid<=0; s2_valid<=0; out_enable<=0;
        end else begin
            s0_valid<=in_enable && (!enable || last_input);
            s1_valid<=s0_valid;
            s2_valid<=s1_valid;
            out_enable<=s2_valid;
            if (in_enable) begin
                if (!enable || !supported || last_input) input_count<=0;
                else input_count<=input_count+1'b1;
            end
        end
    end
    always @(posedge clk) begin
        if (in_enable) begin
            if (!enable) begin
                s0_sum<=input_ext;
                s0_shift<=0;
            end else if (supported) begin
                accumulator<=input_count==0 ? input_ext : total;
                if (last_input) begin
                    s0_sum<=input_count==0 ? input_ext : total;
                    s0_shift<=input_shift;
                end
            end
        end
        if (s0_valid) begin
            s1_negative<=extended_sum<0;
            s1_magnitude<=extended_sum<0 ? $unsigned(-extended_sum) : $unsigned(extended_sum);
            s1_shift<=s0_shift;
        end
        if (s1_valid) begin
            // 평균은 입력 범위 안에 있으므로 WORD_W 비트만 저장하면 충분하다.
            s2_rounded<=rounded_magnitude[WORD_W-1:0];
            s2_negative<=s1_negative;
        end
        if (s2_valid)
            out_data<=s2_negative ? -$signed(s2_rounded[WORD_W-1:0]) : $signed(s2_rounded[WORD_W-1:0]);
    end
endmodule
