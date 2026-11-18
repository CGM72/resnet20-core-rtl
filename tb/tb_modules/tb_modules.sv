`timescale 1ns/1ps
// Six real module instances. Values and cycle-valids come from an independent Python model.
module tb_modules #(
	parameter integer WORD_W=16,
	parameter integer FRAC_W=10
);
	localparam integer MOD_CNT=6;
	reg clk=0;
	reg nrst=0;
	reg enable=0;
	reg in_enable=0;
	reg [15:0] iteration=0;
	reg signed [WORD_W-1:0] in_data=0, kernel_data=0, bias_data=0, skip_data=0;
	wire [MOD_CNT-1:0] result_valid;
	wire signed [WORD_W-1:0] result_data[MOD_CNT];
	integer fd,rc,cycle=0,i;
	integer r,e,v,n,d,k,b,s;
	integer ev[MOD_CNT],ed[MOD_CNT],received[MOD_CNT];
	string vector_path;
	always #5 clk=~clk;
	mac #(.BITWIDTH(WORD_W),.FRAC_W(FRAC_W)) u_mac (
		.clk(clk),.nrst(nrst),.enable(enable),.iteration(iteration),.in_enable(in_enable),
		.in_data(in_data),.kernel_data(kernel_data),.out_enable(result_valid[0]),.out_data(result_data[0])
	);
	mac_accumulate #(.BITWIDTH(WORD_W),.FRAC_W(FRAC_W)) u_biased_mac (
		.clk(clk),.nrst(nrst),.enable(enable),.iteration(iteration),.in_enable(in_enable),
		.in_data(in_data),.kernel_data(kernel_data),.bias_data(bias_data),.last_input(),
		.out_enable(result_valid[1]),.out_data(result_data[1])
	);
	residual #(.BITWIDTH(WORD_W)) u_residual (
		.clk(clk),.nrst(nrst),.enable(enable),.in_enable(in_enable),.in_data(in_data),.skip_data(skip_data),
		.out_enable(result_valid[2]),.out_data(result_data[2])
	);
	relu #(.BITWIDTH(WORD_W)) u_relu (
		.clk(clk),.nrst(nrst),.enable(enable),.in_enable(in_enable),.in_data(in_data),
		.out_enable(result_valid[3]),.out_data(result_data[3])
	);
	pooling #(.BITWIDTH(WORD_W)) u_pooling (
		.clk(clk),.nrst(nrst),.enable(enable),.iteration(iteration),.in_enable(in_enable),.in_data(in_data),
		.out_enable(result_valid[4]),.out_data(result_data[4])
	);
	general_average_pooling #(.BITWIDTH(WORD_W)) u_gap (
		.clk(clk),.nrst(nrst),.enable(enable),.iteration(iteration),.in_enable(in_enable),.in_data(in_data),
		.out_enable(result_valid[5]),.out_data(result_data[5])
	);
	initial begin
		vector_path="build/unit_vectors.txt";
		if ($value$plusargs("vectors_path=%s",vector_path)) begin
			$display("vectors=%s",vector_path);
		end
		fd=$fopen(vector_path,"r");
		if (!fd) $fatal(1,"Missing unit vectors: %s",vector_path);
		for(i=0;i<MOD_CNT;i=i+1) received[i]=0;
		while(!$feof(fd)) begin
			rc=$fscanf(fd,"%d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d\n",
				r,e,v,n,d,k,b,s,ev[0],ed[0],ev[1],ed[1],ev[2],ed[2],ev[3],ed[3],ev[4],ed[4],ev[5],ed[5]);
			if(rc!=20) $fatal(1,"Malformed unit vector cycle %0d fields=%0d",cycle,rc);
			@(negedge clk);
			nrst=r;
			enable=e;
			in_enable=v;
			iteration=n;
			in_data=d;
			kernel_data=k;
			bias_data=b;
			skip_data=s;
			@(posedge clk);
			#1;
			for(i=0;i<MOD_CNT;i=i+1) begin
				if(result_valid[i] !== (ev[i]!=0)) $fatal(1,"Module %0d cycle %0d valid mismatch",i,cycle);
				if(ev[i] && $signed(result_data[i]) !== $signed(ed[i][WORD_W-1:0]))
					$fatal(1,"Module %0d cycle %0d expected=%0d actual=%0d",i,cycle,ed[i],result_data[i]);
				received[i]=received[i]+ev[i];
			end
			cycle=cycle+1;
		end
		$fclose(fd);
		$display("[ PASS ] modules WORD_W=%0d FRAC_W=%0d cycles=%0d",WORD_W,FRAC_W,cycle);
		for(i=0;i<MOD_CNT;i=i+1) $display("[ PASS ] module %0d outputs=%0d",i,received[i]);
		$display("[ PASS ] ALL TESTS PASSED");
		$finish;
	end
	initial begin
		#10000000;
		$fatal(1,"Unit timeout");
	end
endmodule
