import os
from pathlib import Path
import shutil
import subprocess
import sys


# Send the Vivado commands through stdin so both launchers use the same flow.
VIVADO_COMMANDS = """\
if {[catch {
    set root [file normalize $::env(TB_CORE_SYNTH_ROOT)]
    set board_dir [file join $root fpga zedboard]
    # Core OOC needs the FPGA part and clock only; board pin/PS presets belong to the system top.
    set part xc7z020clg484-1
    puts "ZedBoard core target: $part"

    set compute_rtl [file join $root rtl compute]
    foreach source {mac.v residual.v relu.v pooling.v general_average_pooling.v core.sv} {
        read_verilog -sv [file join $compute_rtl $source]
    }
    synth_design -top core -part $part -mode out_of_context
    read_xdc [file join $board_dir core_ooc.xdc]

    report_utilization -file utilization.rpt
    report_timing_summary -file timing_summary.rpt
    write_checkpoint -force core.dcp
    write_verilog -mode funcsim -force core_funcsim.v
} message]} {
    puts stderr $::errorInfo
    exit 1
}
exit 0
"""


def main():
    vivado_name = "vivado.bat" if os.name == "nt" else "vivado"
    vivado = shutil.which(vivado_name)
    if not vivado:
        print(f"[ ERROR ] {vivado_name} not found. Add Vivado bin to PATH.", file=sys.stderr)
        return 1

    root = Path(__file__).resolve().parents[1]
    build = root / "build" / "synth" / "tb_core" / "zedboard" / "compute"
    build.mkdir(parents=True, exist_ok=True)
    log = build / "synthesis.log"
    env = os.environ.copy()
    env["TB_CORE_SYNTH_ROOT"] = root.as_posix()

    print("[ INFO ] Synthesizing rtl/compute core for ZedBoard", flush=True)
    try:
        result = subprocess.run(
            [vivado, "-mode", "tcl", "-log", "synthesis.log", "-journal", "synthesis.jou"],
            cwd=build,
            env=env,
            input=VIVADO_COMMANDS,
            text=True,
        )
    except OSError as error:
        print(f"[ ERROR ] Could not start Vivado: {error}", file=sys.stderr)
        return 1

    artifacts = (build / "core.dcp", build / "core_funcsim.v")
    if result.returncode or any(not file.is_file() or not file.stat().st_size for file in artifacts):
        print(f"[ ERROR ] Synthesis failed. See {log}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
