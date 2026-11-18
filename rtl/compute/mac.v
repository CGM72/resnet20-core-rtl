`timescale 1ns/1ps

//======================================================================
// mac: 첨부 양식의 bias 없는 단독 MAC 포트. 기본 수치 형식은 Q5.10.
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
		.clk(clk), .nrst(nrst), .enable(enable), .iteration(iteration),
		.in_enable(in_enable), .in_data(in_data), .kernel_data(kernel_data),
		.bias_data({BITWIDTH{1'b0}}), .last_input(),
		.out_enable(result_valid), .out_data(result_data)
	);
	always @* begin
		out_enable = result_valid;
		out_data = result_data;
	end
endmodule

//======================================================================
// mac_accumulate: 단일 곱셈기 + 넓은 누산기 + 두 단계 valid 파이프라인.
// 첫 유효 항에서만 bias를 Q(2*FRAC_W) 단위로 올려 더한다.
// N번째 유효 항까지 누산한 뒤 Q(FRAC_W) 반올림/포화를 한 번 수행한다.
// last_input은 마지막 MAC 항을 수신하는 상승 에지의 경계 표시이다.
// enable=0은 우회. enable=1, iteration=0은 입력 폐기/부분합 초기화이다.
//======================================================================
module mac_accumulate #(
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
	input  wire signed [BITWIDTH-1:0] bias_data,

	output wire last_input,
	output reg out_enable,
	output reg signed [BITWIDTH-1:0] out_data
);
	localparam integer WORD_W = BITWIDTH;
	localparam integer ITER_W = BITWIDTH_MAC_ITERATION;
	localparam integer PROD_W = WORD_W + WORD_W;
	localparam integer ACC_W = PROD_W + ITER_W;
	localparam integer RND_W = ACC_W + 1;
	localparam [RND_W-1:0] ONE = {{(RND_W-1){1'b0}},1'b1};
	localparam [RND_W-1:0] HALF = FRAC_W > 0 ? (ONE << (FRAC_W-1)) : 0;
	localparam signed [ACC_W-1:0] SAT_MAX = {{(ACC_W-WORD_W){1'b0}},1'b0,{(WORD_W-1){1'b1}}};
	localparam signed [ACC_W-1:0] SAT_MIN = {{(ACC_W-WORD_W){1'b1}},1'b1,{(WORD_W-1){1'b0}}};

	//==================================================================
	// 수치 함수: 부호 확장 절댓값으로 음수 최솟값과 양/음 tie를 대칭 처리.
	//==================================================================
	function signed [ACC_W-1:0] round_shift;
		input signed [ACC_W-1:0] value;
		reg signed [RND_W-1:0] extended;
		reg [RND_W-1:0] magnitude;
		reg [RND_W-1:0] rounded;
		begin
			extended = {value[ACC_W-1],value};
			magnitude = extended < 0 ? $unsigned(-extended) : $unsigned(extended);
			rounded = (magnitude + HALF) >> FRAC_W;
			round_shift = extended < 0 ? -$signed(rounded[ACC_W-1:0]) : $signed(rounded[ACC_W-1:0]);
		end
	endfunction
	function signed [WORD_W-1:0] saturate;
		input signed [ACC_W-1:0] value;
		begin
			if (value > SAT_MAX) begin
				saturate = SAT_MAX[WORD_W-1:0];
			end
			else if (value < SAT_MIN) begin
				saturate = SAT_MIN[WORD_W-1:0];
			end
			else begin
				saturate = value[WORD_W-1:0];
			end
		end
	endfunction

	//==================================================================
	// Datapath: 첫 항은 bias부터, 이후 항은 저장된 부분합부터 누산한다.
	//==================================================================
	reg signed [ACC_W-1:0] accumulator;
	reg [ITER_W-1:0] input_count;
	reg pending_enable;
	reg signed [WORD_W-1:0] pending_data;
	(* use_dsp="yes" *) wire signed [PROD_W-1:0] product;
	wire signed [ACC_W-1:0] product_ext;
	wire signed [ACC_W-1:0] bias_ext;
	wire signed [ACC_W-1:0] base_sum;
	wire signed [ACC_W-1:0] total;
	assign product = in_data * kernel_data;
	assign product_ext = {{(ACC_W-PROD_W){product[PROD_W-1]}},product};
	assign bias_ext = {{(ACC_W-WORD_W){bias_data[WORD_W-1]}},bias_data};
	assign base_sum = input_count == 0 ? (bias_ext <<< FRAC_W) : accumulator;
	assign total = base_sum + product_ext;
	assign last_input = enable && in_enable && (iteration != 0) && (input_count == iteration-1'b1);

	always @(posedge clk or negedge nrst) begin
		if (!nrst) begin
			accumulator <= 0;
			input_count <= 0;
			pending_enable <= 0;
			pending_data <= 0;
			out_enable <= 0;
			out_data <= 0;
		end
		else begin
			// 1단계 결과를 2단계로 전달한다. 입력 bubble은 valid=0으로 전파한다.
			out_enable <= pending_enable;
			if (pending_enable) begin
				out_data <= pending_data;
			end
			pending_enable <= 0;
			if (in_enable) begin
				if (!enable) begin
					accumulator <= 0;
					input_count <= 0;
					pending_enable <= 1;
					pending_data <= in_data;
				end
				else if (iteration == 0) begin
					accumulator <= 0;
					input_count <= 0;
				end
				else if (last_input) begin
					pending_enable <= 1;
					pending_data <= saturate(round_shift(total));
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
