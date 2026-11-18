`timescale 1ns/1ps

//======================================================================
// GAP: 같은 채널의 N개 공간 값을 합산하고 최근접 평균을 출력한다.
// 외부는 채널별 공간 창을 연속 공급한다. 평균은 입력과 같은 Q scale이다.
// valid-only 포트와 2단계 지연을 유지하기 위해 폭을 제한한 조합 나눗셈 사용.
// 임의 양수 N 지원. timing critical path는 Vivado에서 확인해야 한다.
// enable=0은 우회, 활성 iteration=0은 입력 폐기/부분합 초기화.
//======================================================================
module general_average_pooling #(
	parameter integer BITWIDTH = 16,
	parameter integer BITWIDTH_GAP_ITERATION = 16
)(
	input  wire clk,
	input  wire nrst,
	input  wire enable,
	input  wire in_enable,
	input  wire [BITWIDTH_GAP_ITERATION-1:0] iteration,
	input  wire signed [BITWIDTH-1:0] in_data,

	output reg out_enable,
	output reg signed [BITWIDTH-1:0] out_data
);
	localparam integer WORD_W = BITWIDTH;
	localparam integer ITER_W = BITWIDTH_GAP_ITERATION;
	localparam integer SUM_W = WORD_W + ITER_W;
	localparam integer RND_W = SUM_W + 1;
	reg signed [SUM_W-1:0] accumulator;
	reg [ITER_W-1:0] input_count;
	reg pending_enable;
	reg signed [SUM_W-1:0] pending_sum;
	reg [ITER_W-1:0] pending_divisor;
	wire signed [SUM_W-1:0] input_ext;
	wire signed [SUM_W-1:0] total;
	assign input_ext = {{(SUM_W-WORD_W){in_data[WORD_W-1]}},in_data};
	assign total = accumulator + input_ext;

	//==================================================================
	// 평균 함수: unsigned 절댓값으로 나누고 부호를 복원한다.
	// 합/양의 N의 평균은 입력 범위 내이므로 추가 포화는 필요 없다.
	//==================================================================
	function signed [WORD_W-1:0] round_mean;
		input signed [SUM_W-1:0] value;
		input [ITER_W-1:0] divisor;
		reg signed [RND_W-1:0] extended;
		reg [RND_W-1:0] magnitude;
		reg [RND_W-1:0] denominator;
		reg [RND_W-1:0] quotient;
		begin
			extended = {value[SUM_W-1],value};
			magnitude = extended < 0 ? $unsigned(-extended) : $unsigned(extended);
			// 비활성 클럭에도 조합 나눗셈의 제수가 0이 되지 않도록 방어한다.
			denominator = divisor == 0 ? {{(RND_W-1){1'b0}},1'b1} : {{(RND_W-ITER_W){1'b0}},divisor};
			quotient = (magnitude + (denominator >> 1)) / denominator;
			round_mean = extended < 0 ? -$signed(quotient[WORD_W-1:0]) : $signed(quotient[WORD_W-1:0]);
		end
	endfunction
	always @(posedge clk or negedge nrst) begin
		if (!nrst) begin
			accumulator <= 0;
			input_count <= 0;
			pending_sum <= 0;
			pending_divisor <= 1;
			pending_enable <= 0;
			out_enable <= 0;
			out_data <= 0;
		end
		else begin
			out_enable <= pending_enable;
			if (pending_enable) begin
				out_data <= round_mean(pending_sum,pending_divisor);
			end
			pending_enable <= 0;
			if (in_enable) begin
				if (!enable) begin
					accumulator <= 0;
					input_count <= 0;
					pending_sum <= input_ext;
					pending_divisor <= 1;
					pending_enable <= 1;
				end
				else if (iteration == 0) begin
					accumulator <= 0;
					input_count <= 0;
				end
				else if (input_count == iteration-1'b1) begin
					pending_sum <= total;
					pending_divisor <= iteration;
					pending_enable <= 1;
					accumulator <= 0;
					input_count <= 0;
				end
				else begin
					accumulator <= total;
					input_count <= input_count + 1'b1;
				end
			end
		end
	end
endmodule
