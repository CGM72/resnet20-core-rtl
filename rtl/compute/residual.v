`timescale 1ns/1ps

//======================================================================
// Residual: 정렬된 main/skip을 같은 Q scale에서 더하고 signed 포화한다.
// enable=0이면 우회한다. 두 단계 레지스터로 valid와 값을 함께 전달한다.
// skip의 시간 정렬은 core에서, 공간/채널 주소 정렬은 외부에서 수행한다.
//======================================================================
module residual #(
	parameter integer BITWIDTH = 16
)(
	input  wire clk,
	input  wire nrst,
	input  wire enable,
	input  wire in_enable,
	input  wire signed [BITWIDTH-1:0] in_data,
	input  wire signed [BITWIDTH-1:0] skip_data,

	output reg out_enable,
	output reg signed [BITWIDTH-1:0] out_data
);
	localparam integer WORD_W = BITWIDTH;
	localparam integer SUM_W = WORD_W + 1;
	localparam signed [SUM_W-1:0] SAT_MAX = {1'b0,1'b0,{(WORD_W-1){1'b1}}};
	localparam signed [SUM_W-1:0] SAT_MIN = {1'b1,1'b1,{(WORD_W-1){1'b0}}};
	reg pending_enable;
	reg signed [WORD_W-1:0] pending_data;
	wire signed [SUM_W-1:0] main_ext;
	wire signed [SUM_W-1:0] skip_ext;
	assign main_ext = {in_data[WORD_W-1],in_data};
	assign skip_ext = {skip_data[WORD_W-1],skip_data};

	//==================================================================
	// 한 비트 넓은 합으로 overflow를 검출하고 INT16 범위로 제한한다.
	//==================================================================
	function signed [WORD_W-1:0] saturate;
		input signed [SUM_W-1:0] value;
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
	always @(posedge clk or negedge nrst) begin
		if (!nrst) begin
			pending_enable <= 0;
			pending_data <= 0;
			out_enable <= 0;
			out_data <= 0;
		end
		else begin
			pending_enable <= in_enable;
			if (in_enable) begin
				pending_data <= enable ? saturate(main_ext + skip_ext) : in_data;
			end
			out_enable <= pending_enable;
			if (pending_enable) begin
				out_data <= pending_data;
			end
		end
	end
endmodule
