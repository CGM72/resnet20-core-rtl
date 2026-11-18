# Vivado command sequencing/error handling only. All Vivado and export APIs are stubbed.
source [file normalize [file join [file dirname [info script]] .. .. scripts analyze_core.tcl]]
set test_root [file join $core_analysis::root build analysis_launcher_test]
file mkdir [file join $test_root rtl compute]
file mkdir [file join $test_root scripts]
foreach file {mac.v residual.v relu.v pooling.v general_average_pooling.v core.sv} {
    file copy -force [file join $core_analysis::root rtl compute $file] [file join $test_root rtl compute $file]
}
file copy -force [file join $core_analysis::root scripts export_analysis.py] [file join $test_root scripts export_analysis.py]
set core_analysis::root $test_root
set project ""
set commands {}
set route_fails 0
set preflight_fails 0
proc get_arg {arguments name} {
    set index [lsearch -exact $arguments $name]
    if {$index < 0} {error "Missing argument $name: $arguments"}
    return [lindex $arguments [expr {$index+1}]]
}
proc current_project {args} {
    if {$::project eq ""} {return -code error {ERROR: [Coretcl 2-88] No projects are currently open.}}
    return $::project
}
rename exec test_analysis_real_exec
proc exec {args} {
    set mode [lindex $args 2]
    if {$mode eq "check"} {
        if {$::preflight_fails} {error "Pillow missing (test fixture)"}
        lappend ::commands check
    } elseif {$mode eq "init"} {
        set ::last_directory [get_arg $args --results]
        set ::last_period [get_arg $args --period]
        lappend ::commands init
    } elseif {$mode eq "export"} {
        lappend ::commands "export_[get_arg $args --stage]"
    } else {error "Unexpected exporter mode $mode"}
    return "Export stub: command-dispatch test only"
}
proc create_project {args} {
    set ::project core_analysis
    lappend ::commands create
    if {![string match "*-in_memory*" $args]} {error "Expected in-memory project"}
}
proc read_verilog {args} {
    if {![file isfile [lindex $args end]]} {error "Missing RTL"}
    lappend ::commands read
}
proc synth_design {args} {
    if {[get_arg $args -top] ne "core" || [get_arg $args -mode] ne "out_of_context"} {error "Wrong synthesis scope"}
    lappend ::commands synth
}
proc read_xdc {file} {
    set fd [open $file r]
    set text [read $fd]
    close $fd
    if {![string match "*create_clock*core_clk*" $text]} {error "Missing clock constraint"}
    if {[string first "-period $::last_period " $text] < 0} {error "Clock period mismatch"}
    lappend ::commands clock
}
proc report_file {args} {
    set file [get_arg $args -file]
    set fd [open $file w]
    puts $fd "STUB REPORT - NOT A VIVADO MEASUREMENT"
    close $fd
}
proc report_timing_summary {args} {report_file {*}$args}
proc report_timing {args} {report_file {*}$args}
proc report_utilization {args} {report_file {*}$args}
proc check_timing {args} {report_file {*}$args}
proc report_drc {args} {report_file {*}$args}
proc report_route_status {args} {report_file {*}$args}
proc write_checkpoint {args} {
    set fd [open [lindex $args end] w]
    puts $fd "STUB CHECKPOINT - NOT AN FPGA DESIGN"
    close $fd
}
proc opt_design {} {lappend ::commands opt}
proc place_design {} {lappend ::commands place}
proc phys_opt_design {} {lappend ::commands phys}
proc route_design {} {
    lappend ::commands route
    if {$::route_fails} {error "Injected route failure"}
}
proc read_latest {} {
    set fd [open [file join $::core_analysis::root build analysis core latest.txt] r]
    set data [string trim [read $fd]]
    close $fd
    return $data
}
set first [core_analysis::run core.sv 10.0]
set expected {check init create read read read read read read clock synth export_post_synth opt place phys route export_post_route}
if {$commands ne $expected} {error "Wrong analysis command sequence: $commands"}
if {[read_latest] ne $first || $last_period != 10} {error "Wrong latest run or period"}
puts "PASS: six actual RTL files, clock before OOC synth, post-synth export, place/route, post-route export"
set project ""
set commands {}
set second [core_analysis::run core.sv 20.0]
if {$first eq $second || $last_period != 20} {error "Run separation or requested period failed"}
puts "PASS: rerun has a fresh result directory and requested clock period"
set project ""
set route_fails 1
if {![catch {core_analysis::run core.sv 10.0} message] || $message ne "Injected route failure"} {error "Expected route failure"}
if {[read_latest] ne $second} {error "Failed run replaced last successful run"}
puts "PASS: failed implementation preserves previous successful latest.txt"
set route_fails 0
set project user_project
set commands {}
if {![catch {core_analysis::run core.sv 10.0} message] || ![string match "Save/close*" $message]} {error "Open project not protected"}
if {[lsearch -exact $commands create] >= 0} {error "Overwrote open project"}
puts "PASS: existing user project protected"
set project ""
set preflight_fails 1
set commands {}
if {![catch {core_analysis::run core.sv 10.0} message] || ![string match "Pillow missing*" $message]} {error "Expected preflight failure"}
if {[lsearch -exact $commands create] >= 0} {error "Analysis started without renderer dependency"}
puts "PASS: missing image dependency stops before synthesis"
if {![catch {core_analysis::run core.v 10.0} message] || ![string match "Supported RTL*" $message]} {error "Wrong RTL filename accepted"}
puts "PASS: actual top filename core.sv enforced"
puts "PASS: analysis launcher regression; Vivado/export commands stubbed, no device measurements"
