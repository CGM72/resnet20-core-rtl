"""Exercise an unrelated RTL/top/clock/TB using project.tcl only; compile recorded files."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[2]

def run(args, cwd=None):
    result=subprocess.run(args,cwd=cwd,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    if result.returncode:
        raise RuntimeError(result.stdout)
    return result.stdout


def check():
    with tempfile.TemporaryDirectory(prefix='fpga reuse ') as temp:
        p=Path(temp)
        (p/'rtl/custom/include').mkdir(parents=True)
        (p/'tb/tb_foreign').mkdir(parents=True)
        (p/'scripts').mkdir()
        shutil.copyfile(ROOT/'scripts/export_analysis.py',p/'scripts/export_analysis.py')
        (p/'project.tcl').write_text('''namespace eval ::fpga_project {
variable settings [dict create part xc7a35tcpg236-1 top gain_block clock_port sample_clk period_ns 12.5 \\
rtl_files {rtl/custom/implementation.sv} include_dirs {rtl/custom/include} defines {DO_GAIN} xdc_files {}]
}
''')
        (p/'rtl/custom/include/gain.svh').write_text('`define GAIN_SHIFT 1\n')
        (p/'rtl/custom/implementation.sv').write_text('''`include "gain.svh"
module gain_block(input wire sample_clk, input wire valid, input wire signed [7:0] sample,
                  output reg valid_out, output reg signed [7:0] result);
always @(posedge sample_clk) begin
    valid_out <= valid;
`ifdef DO_GAIN
    result <= sample <<< `GAIN_SHIFT;
`else
    result <= sample;
`endif
end
endmodule
''')
        (p/'tb/tb_foreign/tb_foreign.f').write_text('tb_foreign.sv\n')
        (p/'tb/tb_foreign/tb_foreign.sv').write_text('''`timescale 1ns/1ps
module tb_foreign;
reg sample_clk=0,valid=0;
reg signed [7:0] sample=0;
wire valid_out;
wire signed [7:0] result;
gain_block whatever_instance(.*);
always #5 sample_clk=~sample_clk;
initial begin
    for(integer i=0;i<10;i=i+1) begin
        @(negedge sample_clk);sample=i-5;valid=1;
        @(posedge sample_clk);#1;
        if(valid_out!==1 || result!==2*(i-5)) $fatal(1,"Foreign module mismatch");
    end
    $display("PASS foreign module numeric simulation");
    $finish;
end
endmodule
''')
        log=run(['tclsh',str(ROOT/'verification/tools/test_workflows.tcl'),str(p)],cwd=ROOT)
        assert 'PASS generic workflow tests' in log
        print('\n'.join(line for line in log.splitlines() if line.startswith('PASS')))
        iv=os.environ.get('IVERILOG') or shutil.which('iverilog')
        vv=os.environ.get('VVP') or shutil.which('vvp')
        if not iv or not vv:
            raise RuntimeError('Set IVERILOG/VVP or add Icarus Verilog to PATH for the actual foreign-module simulation')
        command=[iv]
        if os.environ.get('IVERILOG_BASE'):command+=['-B',os.environ['IVERILOG_BASE']]
        command+=['-g2012','-s','tb_foreign','-o',str(p/'simulation.vvp')]
        for directory in (p/'includes.txt').read_text().splitlines():command+=['-I',directory]
        for define in (p/'defines.txt').read_text().splitlines():command+=['-D'+define]
        command+=(p/'design.txt').read_text().splitlines()+(p/'tests.txt').read_text().splitlines()
        run(command)
        output=run([vv,str(p/'simulation.vvp')])
        assert 'PASS foreign module numeric simulation' in output,output
        print(output.strip())

if __name__=='__main__':check()
