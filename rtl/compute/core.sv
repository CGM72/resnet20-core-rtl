`timescale 1ns/1ps
//======================================================================
// core: 첨부의 valid-only 단일 lane 포트와 고정 5단계 datapath를 구현한다.
// MAC → Residual → ReLU → MaxPool → GAP. 각 단계는 비활성 시 우회한다.
// 설정은 입력 시작 전부터 전체 pipeline이 비워질 때까지 유지해야 한다.
// residual 활성: MAC N항 다음 유효 in_data 하나가 skip이며 MAC에 넣지 않는다.
// ready 포트가 없으므로 출력은 out_enable=1인 매 클럭 반드시 수신한다.
// 레이어/주소/패딩/메모리/Controller는 이 모듈에 포함하지 않는다.
//======================================================================
module core #(
    // bitwidth
    parameter integer BITWIDTH    = 16,
    parameter integer BITWIDTH_MAC_ITERATION     = 16,
    parameter integer BITWIDTH_POOLING_ITERATION = 16,
    parameter integer BITWIDTH_GAP_ITERATION     = 16,
    // parallelism
    parameter integer PARALLEL_PC                = 1,
    parameter integer PARALLEL_PF                = 1,
    parameter integer FRAC_W                     = 10
)(
    input  wire                                  clk,
    input  wire                                  nrst,

    // config
    input  wire                                  mac_enable,
    input  wire [BITWIDTH_MAC_ITERATION-1:0]     mac_iteration,
    input  wire                                  residual_enable,
    input  wire                                  relu_enable,
    input  wire                                  pooling_enable,
    input  wire [BITWIDTH_POOLING_ITERATION-1:0] pooling_iteration,
    input  wire                                  gap_enable,
    input  wire [BITWIDTH_GAP_ITERATION-1:0]     gap_iteration,
    
    // input
    input  wire                                  in_enable,
    input  wire [BITWIDTH-1:0]                   in_data,
    input  wire [BITWIDTH-1:0]                   kernel_data,
    input  wire [BITWIDTH-1:0]                   bias_data,
    
    // output
    output reg                                   out_enable,
    output reg  [BITWIDTH-1:0]                   out_data
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

	wire mac_last_input;
	wire mac_valid, residual_valid, relu_valid, pooling_valid, gap_valid;
	wire signed [BITWIDTH-1:0] mac_data, residual_data, relu_data, pooling_data, gap_data;
	wire use_residual;
	reg waiting_for_skip;
	reg mac_held_valid, skip_held_valid;
	reg signed [BITWIDTH-1:0] mac_held_data, skip_held_data;
	wire skip_valid;
	wire pair_valid;
	wire residual_in_valid;
	wire signed [BITWIDTH-1:0] residual_main;
	wire signed [BITWIDTH-1:0] residual_skip;

	//==================================================================
	// Skip rendezvous: MAC 결과와 후속 skip 중 먼저 온 값을 한 개 저장한다.
	// 다음 유효 입력이 skip이므로, 공백이 있어도 skip을 MAC 항으로 세지 않는다.
	// 이전 쌍이 완성될 때까지 결과를 보존하며 새 쌍에 누출하지 않는다.
	//==================================================================
	assign use_residual = mac_enable && residual_enable;
	assign skip_valid = waiting_for_skip && in_enable;
	assign pair_valid = (mac_valid || mac_held_valid) && (skip_valid || skip_held_valid);
	assign residual_in_valid = use_residual ? pair_valid : mac_valid;
	assign residual_main = mac_held_valid ? mac_held_data : mac_data;
	assign residual_skip = skip_held_valid ? skip_held_data : $signed(in_data);
	always @(posedge clk or negedge nrst) begin
		if (!nrst) begin
			waiting_for_skip <= 0;
			mac_held_valid <= 0;
			skip_held_valid <= 0;
			mac_held_data <= 0;
			skip_held_data <= 0;
		end
		else begin
			if (skip_valid) begin
				waiting_for_skip <= 0;
			end
			else if (use_residual && mac_last_input) begin
				waiting_for_skip <= 1;
			end
			if (!use_residual || pair_valid) begin
				mac_held_valid <= 0;
				skip_held_valid <= 0;
			end
			else begin
				if (mac_valid) begin
					mac_held_valid <= 1;
					mac_held_data <= mac_data;
				end
				if (skip_valid) begin
					skip_held_valid <= 1;
					skip_held_data <= in_data;
				end
			end
		end
	end

	//==================================================================
	// 실제 연산 모듈 연결. 각 단계의 out_enable을 다음 단계 in_enable로 연결.
	//==================================================================
	mac_accumulate #(
		.BITWIDTH(BITWIDTH),
		.BITWIDTH_MAC_ITERATION(BITWIDTH_MAC_ITERATION),
		.FRAC_W(FRAC_W)
	) u_mac (
		.clk(clk), .nrst(nrst), .enable(mac_enable), .iteration(mac_iteration),
		.in_enable(in_enable && !waiting_for_skip),
		.in_data(in_data), .kernel_data(kernel_data), .bias_data(bias_data),
		.last_input(mac_last_input), .out_enable(mac_valid), .out_data(mac_data)
	);
	residual #(.BITWIDTH(BITWIDTH)) u_residual (
		.clk(clk), .nrst(nrst), .enable(use_residual),
		.in_enable(residual_in_valid), .in_data(residual_main), .skip_data(residual_skip),
		.out_enable(residual_valid), .out_data(residual_data)
	);
	relu #(.BITWIDTH(BITWIDTH)) u_relu (
		.clk(clk), .nrst(nrst), .enable(relu_enable),
		.in_enable(residual_valid), .in_data(residual_data),
		.out_enable(relu_valid), .out_data(relu_data)
	);
	pooling #(
		.BITWIDTH(BITWIDTH),
		.BITWIDTH_POOLING_ITERATION(BITWIDTH_POOLING_ITERATION)
	) u_pooling (
		.clk(clk), .nrst(nrst), .enable(pooling_enable), .iteration(pooling_iteration),
		.in_enable(relu_valid), .in_data(relu_data),
		.out_enable(pooling_valid), .out_data(pooling_data)
	);
	general_average_pooling #(
		.BITWIDTH(BITWIDTH),
		.BITWIDTH_GAP_ITERATION(BITWIDTH_GAP_ITERATION)
	) u_gap (
		.clk(clk), .nrst(nrst), .enable(gap_enable), .iteration(gap_iteration),
		.in_enable(pooling_valid), .in_data(pooling_data),
		.out_enable(gap_valid), .out_data(gap_data)
	);
	always @* begin
		out_enable = gap_valid;
		out_data = gap_data;
	end

endmodule
