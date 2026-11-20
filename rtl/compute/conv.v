`timescale 1ns/1ps
// Stream one convolution tap per valid clock into the shared bias MAC.
// When residual pairing is enabled, the next valid word after a tap group is
// its skip value. The existing FIFO aligns the skip and convolution result.
module conv #(
    parameter integer BITWIDTH = 16,
    parameter integer BITWIDTH_MAC_ITERATION = 16,
    parameter integer FRAC_W = 10
)(
    input wire clk,
    input wire nrst,
    input wire mac_enable,
    input wire [BITWIDTH_MAC_ITERATION-1:0] mac_iteration,
    input wire use_residual,
    input wire in_enable,
    input wire [BITWIDTH-1:0] in_data,
    input wire [BITWIDTH-1:0] kernel_data,
    input wire [BITWIDTH-1:0] bias_data,
    output wire residual_in_valid,
    output wire signed [BITWIDTH-1:0] residual_main,
    output wire signed [BITWIDTH-1:0] residual_skip
);

    wire mac_last_input;
    reg waiting_for_skip;
    reg mac_held_valid;
    reg signed [BITWIDTH-1:0] mac_held_data;
    wire skip_valid;
    wire pair_valid;
    wire mac_valid;
    wire signed [BITWIDTH-1:0] mac_data;

    //==================================================================
    // MAC의 5단계 지연 동안 먼저 도착한 skip을 순서대로 보존한다.
    // N=1에서 MAC/skip을 매 2클럭 연속 공급해도 여러 skip이 덮어써지지 않는다.
    // 4-entry FIFO + 늦게 도착하는 skip을 기다릴 MAC 결과 1개를 사용한다.
    // skip 수신 전에는 다음 MAC 그룹이 시작되지 않아 MAC 보관 1개면 충분하다.
    //==================================================================
    localparam integer SKIP_DEPTH = 4;
    reg signed [BITWIDTH-1:0] skip_fifo[0:SKIP_DEPTH-1];
    reg [1:0] skip_read, skip_write;
    reg [2:0] skip_count;
    wire skip_push, skip_pop;
    // main/skip 준비 조건과 FIFO 직접 전달 여부를 조합 논리로 결정한다.
    assign skip_valid = waiting_for_skip && in_enable;
    assign pair_valid = (mac_valid || mac_held_valid) && (skip_count != 0 || skip_valid);
    assign residual_in_valid = use_residual ? pair_valid : mac_valid;
    assign residual_main = mac_held_valid ? mac_held_data : mac_data;
    assign residual_skip = skip_count != 0 ? skip_fifo[skip_read] : $signed(in_data);
    assign skip_pop = use_residual && pair_valid && skip_count != 0;
    assign skip_push = use_residual && skip_valid && !(pair_valid && skip_count == 0);

    // 제어 상태: skip 경계, 보관 valid, FIFO 포인터/개수만 관리한다.
    always @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            waiting_for_skip <= 0;
            mac_held_valid <= 0;
            skip_read <= 0;
            skip_write <= 0;
            skip_count <= 0;
        end else begin
            if (skip_valid)
                waiting_for_skip <= 0;
            else if (use_residual && mac_last_input)
                waiting_for_skip <= 1;
            if (!use_residual) begin
                mac_held_valid <= 0;
                skip_read <= 0;
                skip_write <= 0;
                skip_count <= 0;
            end else begin
                if (pair_valid)
                    mac_held_valid <= 0;
                else if (mac_valid)
                    mac_held_valid <= 1;
                if (skip_push) skip_write <= skip_write + 1'b1;
                if (skip_pop) skip_read <= skip_read + 1'b1;
                case ({skip_push, skip_pop})
                    2'b10:
                        skip_count <= skip_count + 1'b1;
                    2'b01:
                        skip_count <= skip_count - 1'b1;
                    default:
                        skip_count <= skip_count;
                endcase
            end
        end
    end
    // 데이터 저장: valid가 있으므로 FIFO/보관 데이터 자체는 reset하지 않는다.
    always @(posedge clk) begin
        if (skip_push) skip_fifo[skip_write] <= in_data;
        if (use_residual && mac_valid && !pair_valid) mac_held_data <= mac_data;
    end
`ifndef SYNTHESIS
    // 파이프라인 지연을 바꾸는 후속 수정에서 FIFO 용량 위반을 즉시 검출한다.
    always @(posedge clk) if (nrst) begin
        if (skip_push && !skip_pop && skip_count == 3'd4)
            $fatal(1,"conv skip FIFO overflow");
        if (use_residual && mac_valid && mac_held_valid)
            $fatal(1,"conv MAC result overwritten while waiting for skip");
    end
`endif

    // MAC: skip 수신 클럭에는 곱셈 항을 받지 않는다.
    mac_accumulate #(
        .BITWIDTH(BITWIDTH),
        .BITWIDTH_MAC_ITERATION(BITWIDTH_MAC_ITERATION),
        .FRAC_W(FRAC_W)
    ) u_mac (
        .clk(clk),
        .nrst(nrst),
        .enable(mac_enable),
        .iteration(mac_iteration),
        .in_enable(in_enable && !waiting_for_skip),
        .in_data(in_data),
        .kernel_data(kernel_data),
        .bias_data(bias_data),
        .last_input(mac_last_input),
        .out_enable(mac_valid),
        .out_data(mac_data)
    );
endmodule
