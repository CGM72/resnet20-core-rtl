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
    integer expected_due[1024];
    integer cycle=0;
    integer seed=20261118, batch, group_index, tap, terms, value, weight, bias, shortcut_value, last_cycle, skip_cycle, due, result;
    longint signed sum_value, rounded_value;
	integer queued=0,received=0,total=0,j,delay;
	always #5 clk=~clk;
	core dut(.*);
	always @(posedge clk) begin
        cycle=cycle+1;
		#1;
		if(nrst) begin
			if(out_enable!==0 && out_enable!==1) $fatal(1,"Unknown out_enable");
			if(received<queued && expected_due[received]>=0 && cycle==expected_due[received] && out_enable!==1) $fatal(1,"Missing output at exact due cycle %0d",cycle);
            if(out_enable) begin
                if(received<queued && expected_due[received]>=0 && cycle!=expected_due[received]) $fatal(1,"Wrong output cycle actual=%0d expected=%0d",cycle,expected_due[received]);
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
	task expect_word(input integer value, input integer due=-1);
		begin
			expected[queued]=value;
            expected_due[queued]=due;
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

        seed=$urandom(seed);
        // Random whole-core schedule. Compare values AND exact post-edge valid timing.
        // A last MAC input at cycle L yields output L+9 without residual.
        // With skip at S, rendezvous at max(L+2,S) yields output max(L+2,S)+7.
        for(batch=0;batch<40;batch=batch+1) begin
            mac_enable=1;
            residual_enable=$urandom_range(0,1);
            relu_enable=$urandom_range(0,1);
            pooling_enable=0;
            gap_enable=0;
            terms=$urandom_range(1,31);
            mac_iteration=terms;
            for(group_index=0;group_index<8;group_index=group_index+1) begin
                bias=$urandom_range(0,2000)-1000;
                sum_value=bias*1024;
                for(tap=0;tap<terms;tap=tap+1) begin
                    value=$urandom_range(0,4000)-2000;
                    weight=$urandom_range(0,4000)-2000;
                    sum_value=sum_value+value*weight;
                    send(value,weight,tap==0 ? bias : 12345);
                    if(tap<terms-1) bubble($urandom_range(0,3));
                end
                last_cycle=cycle+1;
                rounded_value=sum_value<0 ? -((-sum_value+512)/1024) : (sum_value+512)/1024;
                result=rounded_value>32767 ? 32767 : rounded_value < -32768 ? -32768 : rounded_value;
                if(residual_enable) begin
                    delay=$urandom_range(1,13);
                    bubble(delay-1);
                    shortcut_value=$urandom_range(0,65535)-32768;
                    send(shortcut_value,0,0);
                    skip_cycle=cycle+1;
                    result=result+shortcut_value;
                    result=result>32767 ? 32767 : result < -32768 ? -32768 : result;
                    due=(last_cycle+2>skip_cycle ? last_cycle+2 : skip_cycle)+7;
                end else due=last_cycle+9;
                if(relu_enable && result<0) result=0;
                expect_word(result,due);
            end
            drain();
        end
        mac_enable=0;residual_enable=0;relu_enable=0;
        for(group_index=0;group_index<20;group_index=group_index+1) begin
            send(group_index-10,0,0);
            expect_word(group_index-10,cycle+10);
            bubble($urandom_range(0,2));
        end
        drain();
		$display("[ PASS ] core stream outputs=%0d, skip delays=1/4/7/10/13, grouped Pool/GAP, reset recovery",total);
		$display("[ PASS ] ALL TESTS PASSED");
		$finish;
	end
	initial begin
		#10000000;
		$fatal(1,"Core stream timeout");
	end
endmodule
