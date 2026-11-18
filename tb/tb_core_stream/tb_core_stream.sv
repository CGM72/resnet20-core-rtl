`timescale 1ns/1ps
// Core boundary tests independent of the full-network driver.
module tb_core_stream;
	reg clk=0,nrst=0;
	reg mac_enable=0,residual_enable=0,relu_enable=0,pooling_enable=0,gap_enable=0;
	reg [15:0] mac_iteration=1,pooling_iteration=1,gap_iteration=1;
	reg in_enable=0;
	reg signed [15:0] in_data=0,kernel_data=0,bias_data=0;
	wire out_enable;
	wire signed [15:0] out_data;
	integer expected[1024];
	integer queued=0,received=0,total=0,j,delay;
	always #5 clk=~clk;
	core dut(.*);
	always @(posedge clk) begin
		#1;
		if(nrst) begin
			if(out_enable!==0 && out_enable!==1) $fatal(1,"Unknown out_enable");
			if(out_enable) begin
				if(received>=queued) $fatal(1,"Unexpected core output %0d",out_data);
				if(out_data !== expected[received][15:0])
					$fatal(1,"Core output %0d expected=%0d actual=%0d",received,expected[received],out_data);
				received=received+1;
				total=total+1;
			end
		end
	end
	task reset_unit;
		begin
			@(negedge clk);
			nrst=0;
			in_enable=0;
			queued=0;
			received=0;
			repeat(2) @(negedge clk);
			#1;
			if(out_enable!==0) $fatal(1,"Reset failed");
			nrst=1;
		end
	endtask
	task expect_word(input integer value);
		begin
			expected[queued]=value;
			queued=queued+1;
		end
	endtask
	task send(input integer value,weight,bias);
		begin
			@(negedge clk);
			in_enable=1;
			in_data=value;
			kernel_data=weight;
			bias_data=bias;
		end
	endtask
	task bubble(input integer count);
		begin
			repeat(count) begin
				@(negedge clk);
				in_enable=0;
			end
		end
	endtask
	task drain;
		begin
			bubble(14);
			if(received!=queued) $fatal(1,"Missing outputs received=%0d expected=%0d",received,queued);
		end
	endtask
	initial begin
		reset_unit();
		// All stages bypass, consecutive values plus bubbles.
		for(j=0;j<17;j=j+1) begin
			expect_word(j-8);
			send(j-8,0,0);
			if(j%3==0) bubble(2);
		end
		drain();
		mac_enable=1;
		residual_enable=1;
		// One-tap MAC and skip can be adjacent or separated beyond MAC latency.
		for(delay=1;delay<=13;delay=delay+3) begin
			for(j=0;j<5;j=j+1) begin
				expect_word(70+j);
				send(100+j,1024,0);
				bubble(delay-1);
				send(-30,0,0);
			end
			drain();
		end
		// Combined MAC->Residual->ReLU->Max2->AVG3, no inter-dot drain.
		mac_iteration=2;
		relu_enable=1;
		pooling_enable=1;
		pooling_iteration=2;
		gap_enable=1;
		gap_iteration=3;
		expect_word(1);
		expect_word(11);
		for(j=0;j<12;j=j+1) begin
			send(-9+2*j,1024,0);
			send(0,1024,0);
			send(2,0,0);
		end
		drain();
		// Reset a partially accumulated dot product.
		residual_enable=0;
		relu_enable=0;
		pooling_enable=0;
		gap_enable=0;
		mac_iteration=3;
		send(30000,30000,0);
		reset_unit();
		mac_iteration=1;
		expect_word(-5);
		send(-5,1024,0);
		drain();
		// Reset while waiting for a skip; next data must become a fresh MAC tap.
		residual_enable=1;
		send(999,1024,0);
		bubble(4);
		reset_unit();
		residual_enable=0;
		expect_word(12);
		send(12,1024,0);
		drain();
		// Reset cancels a result already travelling through downstream stages.
		expect_word(777);
		send(777,1024,0);
		bubble(3);
		reset_unit();
		expect_word(13);
		send(13,1024,0);
		drain();
		// Zero iteration produces no output; a new valid configuration recovers.
		mac_iteration=0;
		send(99,1024,0);
		send(99,1024,0);
		drain();
		mac_iteration=1;
		expect_word(14);
		send(14,1024,0);
		drain();
		$display("[ PASS ] core stream outputs=%0d, skip delays=1/4/7/10/13, grouped Pool/GAP, reset recovery",total);
		$display("[ PASS ] ALL TESTS PASSED");
		$finish;
	end
	initial begin
		#100000;
		$fatal(1,"Core stream timeout");
	end
endmodule
