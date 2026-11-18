# Contract checks using Vivado API stubs. No Vivado/FPGA measurements are produced.
source [file normalize [file join [file dirname [info script]] .. .. scripts vivado.tcl]]
set original_root $fpga::root
set project ""
set no_project_errors 1
set actions {}
set loaded_design {}
set loaded_test {}
set properties [dict create]
set route_fails 0
set preflight_fails 0
set probe_only_py 0
proc argument {args key} {
    set i [lsearch -exact $args $key]
    if {$i < 0} {error "Missing $key: $args"}
    return [lindex $args [expr {$i+1}]]
}
proc current_project {args} {
    if {$::project ne ""} {return $::project}
    if {$::no_project_errors} {error {ERROR: [Coretcl 2-88] No projects are currently open.}}
    return ""
}
proc create_project {args} {set ::project [lindex $args 1]; lappend ::actions create}
proc set_property {args} {
    dict set ::properties [list [lindex $args end] [lindex $args 0]] [lindex $args 1]
}
proc get_filesets {name} {return $name}
proc add_files {args} {
    set fs [argument $args -fileset]
    foreach path [lindex $args end] {
        if {![file isfile $path]} {error "Missing added source $path"}
        if {$fs eq "sources_1"} {lappend ::loaded_design $path} else {lappend ::loaded_test $path}
    }
}
proc update_compile_order {args} {}
proc launch_simulation {args} {lappend ::actions simulate}
proc log_wave {args} {}
proc add_wave {args} {}
proc run {args} {lappend ::actions run}
rename exec workflow_real_exec
proc exec {args} {
    if {[lsearch -exact $args -c] >= 0} {
        if {$::probe_only_py && [lrange $args 0 1] ne "py -3"} {error "Interpreter unavailable"}
        return "FPGA_PYTHON_OK"
    }
    set helper_index 1
    if {[lrange $args 0 1] eq "py -3"} {set helper_index 2}
    if {![file isfile [lindex $args $helper_index]]} {error "Missing Python helper"}
    set ::last_python_args $args
    set mode [lindex $args [expr {$helper_index+1}]]
    if {$mode eq "check" && $::preflight_fails} {error "Pillow missing (test stub)"}
    if {$mode eq "init"} {
        set ::last_init $args
    }
    lappend ::actions "exec_$mode"
    return "Python helper stub"
}
proc read_verilog {args} {
    if {![file isfile [lindex $args end]]} {error "Missing RTL"}
    lappend ::loaded_design [lindex $args end]
    lappend ::actions read
    set ::last_read_options [lrange $args 0 end-1]
}
proc read_xdc {file} {
    if {![file isfile $file]} {error "Missing XDC"}
    set fd [open $file r]
    lappend ::constraint_texts [read $fd]
    close $fd
    lappend ::actions xdc
}
proc synth_design {args} {
    set ::last_synth $args
    lappend ::actions synth
}
proc report_file {args} {
    set fd [open [argument $args -file] w]
    puts $fd "STUB REPORT - NOT A MEASUREMENT"
    close $fd
}
foreach name {report_timing_summary report_timing report_utilization check_timing report_route_status report_drc} {
    proc $name {args} {report_file {*}$args}
}
proc write_checkpoint {args} {
    set fd [open [lindex $args end] w]; puts $fd "STUB CHECKPOINT"; close $fd
}
proc write_verilog {args} {
    set fd [open [lindex $args end] w]; puts $fd "STUB NETLIST"; close $fd
}
proc opt_design {} {lappend ::actions opt}
proc place_design {} {lappend ::actions place}
proc phys_opt_design {} {lappend ::actions phys}
proc route_design {} {
    lappend ::actions route
    if {$::route_fails} {error "Injected route failure"}
}
proc reset_mock {} {
    set ::project ""
    set ::actions {}
    set ::properties [dict create]
    set ::loaded_design {}
    set ::loaded_test {}
    set ::constraint_texts {}
}
# All supplied numeric TBs remain usable, with their .f files containing tests only.
foreach mode {0 1} {
    set no_project_errors $mode
    foreach top {tb_modules tb_core_stream tb_core} {
        foreach name [list $top "$top.sv"] {
            reset_mock
            fpga::sim $name
            if {[dict get $properties [list sim_1 top]] ne $top} {error "Wrong TB top"}
            if {[dict get $properties [list sources_1 top]] ne "core"} {error "Wrong design top"}
            if {[llength $loaded_design] != 6 || [llength $loaded_test] != 1} {error "Design/test source ownership mismatch"}
        }
    }
}
puts "PASS supplied testbenches: names/paths/config and both no-project behaviors"
reset_mock
set probe_only_py 1
fpga::sim tb_modules
if {[lrange $last_python_args 0 1] ne "py -3"} {error "Fixture generator lost launcher arguments"}
set probe_only_py 0
puts "PASS fixture generator accepts py -3 command prefix"
set project user_project
set actions {}
if {![catch {fpga::sim tb_core_stream} msg] || ![string match "Save/close*" $msg]} {error "Open project not protected"}
if {[llength $actions]} {error "Changed open project"}
puts "PASS open user project protected"
reset_mock
if {![catch {fpga::sim tb_missing} msg] || ![string match "Missing matching TB files:*" $msg]} {error "Missing TB not caught"}
puts "PASS missing TB rejected before project creation"
# Optional external project, prepared by test_reuse.py. Nothing here requires core/dut/u_mac ports.
if {[llength $argv]} {
    set fpga::root [file normalize [lindex $argv 0]]
    reset_mock
    fpga::sim tb_foreign.sv
    if {[dict get $properties [list sources_1 top]] ne "gain_block"} {error "Custom top ignored"}
    if {[llength $loaded_design] != 1 || ![string match "*implementation.sv" [lindex $loaded_design 0]]} {error "Old core RTL leaked"}
    if {[lsearch -glob $actions exec_*] >= 0} {error "Unregistered TB unexpectedly requires Python fixtures"}
    foreach {name values} [list design $loaded_design tests $loaded_test includes [dict get $properties [list sources_1 include_dirs]] defines [dict get $properties [list sources_1 verilog_define]]] {
        set fd [open [file join $fpga::root "$name.txt"] w]
        foreach value $values {puts $fd $value}
        close $fd
    }
    puts "PASS foreign module: unrelated filename/top/clock/ports and include/define configuration"
    reset_mock
    set probe_only_py 1
    set first [fpga::analyze]
    if {[lrange $last_python_args 0 1] ne "py -3"} {error "Image exporter lost launcher arguments"}
    set probe_only_py 0
    puts "PASS analysis and image export accept py -3 command prefix"
    if {[argument $last_synth -top] ne "gain_block" || [argument $last_synth -part] ne "xc7a35tcpg236-1"} {error "Analysis ignored custom config"}
    if {[argument $last_init --top] ne "gain_block" || [argument $last_init --part] ne "xc7a35tcpg236-1" || [argument $last_init --clock-port] ne "sample_clk"} {error "PNG metadata ignored custom config"}
    if {![string match "*sample_clk*" [lindex $constraint_texts 0]] || ![string match "*-period 12.5*" [lindex $constraint_texts 0]]} {error "Wrong configured clock"}
    if {[lsearch -exact $actions xdc] > [lsearch -exact $actions synth]} {error "Clock applied after synthesis"}
    if {[lsearch -exact $last_read_options -include_dirs] < 0 || [lsearch -exact $last_read_options -define] < 0} {error "Analysis ignored include/define settings"}
    set base [file join $fpga::root build analysis gain_block]
    set fd [open [file join $base latest.txt] r]; set latest [string trim [read $fd]]; close $fd
    if {$latest ne $first} {error "Wrong latest result"}
    reset_mock
    set route_fails 1
    if {![catch {fpga::analyze 20.0} msg] || $msg ne "Injected route failure"} {error "Failure did not propagate"}
    set route_fails 0
    set fd [open [file join $base latest.txt] r]; set latest [string trim [read $fd]]; close $fd
    if {$latest ne $first} {error "Failed run replaced successful latest.txt"}
    puts "PASS custom analysis: period/part/top/clock, source list, ordering and failed-run isolation"
    reset_mock
    set preflight_fails 1
    if {![catch {fpga::analyze} msg] || ![string match "Pillow missing*" $msg]} {error "Preflight failed"}
    set preflight_fails 0
    if {[lsearch -exact $actions create] >= 0} {error "Started synthesis before image dependency check"}
    puts "PASS image dependency checked before synthesis"
    reset_mock
    set fd [open [file join $fpga::root project.tcl] r];set cfg_text [read $fd];close $fd
    set fd [open [file join $fpga::root project.tcl] w]
    puts $fd [string map [list {clock_port sample_clk} {clock_port {}}] $cfg_text]
    close $fd
    set directory [fpga::synth]
    if {![file isfile [file join $directory gain_block_funcsim.v]]} {error "Configured synthesis output name wrong"}
    if {[llength $constraint_texts]} {error "Clockless design received an automatic clock"}
    puts "PASS synthesis-only flow and optional automatic clock use the configuration"
}
foreach value {0 -1 NaN Inf} {
    if {![catch {fpga::period $value}]} {error "Bad period accepted: $value"}
}
puts "PASS generic workflow tests (Vivado APIs stubbed)"
