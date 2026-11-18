# Separate OOC timing/resource flow. No behavioral testbench is used.
# GUI: source scripts/analyze_core.tcl; core_analysis::run core.sv 10.0
# Optional Python path: core_analysis::run core.sv 10.0 {C:/Python312/python.exe}
namespace eval core_analysis {
    variable root [file normalize [file join [file dirname [info script]] ..]]

    proc reports {directory stage python_exe} {
        variable root
        set timing [file join $directory timing]
        set utilization [file join $directory utilization]
        # -name also creates report tabs when run in the Vivado GUI.
        report_timing_summary -delay_type min_max -report_unconstrained \
            -name timing_$stage -file [file join $timing "$stage.rpt"]
        report_timing -delay_type max -max_paths 10 \
            -file [file join $timing "${stage}_setup_paths.rpt"]
        report_timing -delay_type min -max_paths 10 \
            -file [file join $timing "${stage}_hold_paths.rpt"]
        check_timing -verbose -file [file join $timing "${stage}_check_timing.rpt"]
        report_utilization -name utilization_$stage \
            -file [file join $utilization "$stage.rpt"]
        report_utilization -hierarchical \
            -file [file join $utilization "${stage}_hierarchical.rpt"]
        # Parse actual reports. Never fill a missing number with zero or reuse an old image.
        puts [exec $python_exe [file join $root scripts export_analysis.py] export \
            --results $directory --stage $stage]
    }

    proc run {{rtl_file core.sv} {period_ns 10.0} {python_exe python}} {
        variable root
        if {[file tail $rtl_file] ne "core.sv"} {error "Supported RTL top file: core.sv"}
        if {![string is double -strict $period_ns]} {error "Clock period must be a positive finite number in ns"}
        # Python preflight also rejects NaN/Inf and checks Pillow before synthesis begins.
        puts [exec $python_exe [file join $root scripts export_analysis.py] check --period $period_ns]
        set open_project ""
        catch {set open_project [current_project -quiet]}
        if {$open_project ne ""} {
            error "Save/close the current project first. If simulation is open: close_sim -force; close_project"
        }
        # Use the same real design sources as tb_core.f; no reference RTL or Controller stubs.
        set sources {}
        foreach file {mac.v residual.v relu.v pooling.v general_average_pooling.v core.sv} {
            set source [file join $root rtl compute $file]
            if {![file isfile $source]} {error "Missing source $source"}
            lappend sources $source
        }
        set base [file join $root build analysis core]
        set stamp [clock format [clock seconds] -format {run_%Y%m%d_%H%M%S}]
        set directory [file join $base $stamp]
        set suffix 1
        while {[file exists $directory]} {
            set directory [file join $base "${stamp}_$suffix"]
            incr suffix
        }
        foreach child {timing utilization checkpoints} {file mkdir [file join $directory $child]}
        puts "Analysis results: $directory"
        puts [exec $python_exe [file join $root scripts export_analysis.py] init \
            --results $directory --period $period_ns --sources {*}$sources]
        # Queue the run-specific clock XDC before synthesis, so mapping uses the requested target.
        set clock_file [file join $directory core_clock.xdc]
        set fd [open $clock_file w]
        puts $fd [format {create_clock -name core_clk -period %s [get_ports {clk}]} $period_ns]
        close $fd
        if {[catch {
            create_project -in_memory core_analysis -part xc7z020clg484-1
            foreach source $sources {read_verilog -sv $source}
            read_xdc $clock_file
            synth_design -top core -part xc7z020clg484-1 -mode out_of_context
            reports $directory post_synth $python_exe
            write_checkpoint -force [file join $directory checkpoints core_post_synth.dcp]

            opt_design
            place_design
            phys_opt_design
            route_design
            report_route_status -file [file join $directory timing post_route_route_status.rpt]
            reports $directory post_route $python_exe
            report_drc -file [file join $directory timing post_route_drc.rpt]
            write_checkpoint -force [file join $directory checkpoints core_post_route.dcp]
        } message options]} {
            puts stderr "Analysis failed. This run's partial reports are in $directory"
            return -options $options $message
        }
        # Update only after both stages and image exports finish successfully.
        set fd [open [file join $base latest.txt] w]
        puts $fd $directory
        close $fd
        puts "Finished: $directory"
        puts "Timing PNG: [file join $directory timing post_route.png]"
        puts "Utilization PNG: [file join $directory utilization post_route.png]"
        puts "Core OOC only: inspect unconstrained I/O/reset paths before system signoff."
        return $directory
    }
}
