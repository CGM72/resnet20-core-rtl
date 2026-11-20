# Verify file selection and Vivado command order. These stubs are not device measurements.
source [file normalize [file join [file dirname [info script]] .. .. scripts vivado.tcl]]
set original_root $fpga::root
set project "";set actions {};set loaded_design {};set properties {};set route_fails 0;set constraint_texts {};set exec_count 0
proc argument {args key} {set i [lsearch -exact $args $key];if {$i<0} {error "Missing $key"};return [lindex $args [expr {$i+1}]]}
set report_version "report-test-[clock clicks]"
proc version {args} {return $::report_version}
proc get_projects {args} {
 if {$::project eq ""} {return {}}
 return [list $::project]
}
set empty_project_queries 0
proc current_project {args} {
 if {$::project eq ""} {
  incr ::empty_project_queries
  error {ERROR: [Coretcl 2-88] No projects are currently open.}
 }
 return $::project
}
proc create_project {args} {set ::project [lindex $args 1];lappend ::actions create}
proc set_property {args} {dict set ::properties [list [lindex $args end] [lindex $args 0]] [lindex $args 1]}
proc get_filesets {name} {return $name}
proc add_files {args} {
 foreach file [lindex $args end] {if {![file isfile $file]} {error "Missing $file"}}
 if {[argument $args -fileset] eq "sources_1"} {set ::loaded_design [lindex $args end]}
}
proc update_compile_order {args} {}
proc launch_simulation {args} {lappend ::actions simulate}
proc close_sim {args} {if {$args ne "-force"} {error "Missing force close"};lappend ::actions close_sim}
proc close_project {} {set ::project "";lappend ::actions close_project}
proc log_wave {args} {lappend ::actions log_wave}
proc add_wave {args} {lappend ::actions add_wave}
proc run {args} {lappend ::actions run}
rename exec workflow_real_exec
proc exec {args} {
 incr ::exec_count
 if {[lsearch -exact $args -c]>=0} {return FPGA_PYTHON_OK}
 if {[lindex $args 1] ne "-E" || ![file isfile [lindex $args 2]]} {error "Missing Python helper"}
 set ::last_python $args
 return {Image helper stub}
}
proc read_verilog {args} {if {![file isfile [lindex $args end]]} {error "Missing RTL"};lappend ::actions read}
proc read_xdc {file} {set fd [open $file r];lappend ::constraint_texts [read $fd];close $fd;lappend ::actions clock}
proc synth_design {args} {set ::last_synth $args;lappend ::actions synth}
proc report_file {args} {set fd [open [argument $args -file] w];puts $fd {STUB REPORT - NOT MEASURED};close $fd}
foreach name {report_timing check_timing report_route_status report_drc} {proc $name {args} {report_file {*}$args}}
proc report_timing_summary {args} {
 set fd [open [argument $args -file] w]
 puts $fd {WNS(ns) TNS(ns) TNS Failing Endpoints TNS Total Endpoints WHS(ns) THS(ns) THS Failing Endpoints THS Total Endpoints WPWS(ns) TPWS(ns) TPWS Failing Endpoints TPWS Total Endpoints
2.767 0.000 0 1126 0.124 0.000 0 1126 -0.750 -0.750 1 568
STUB TIMING DETAILS}
 close $fd
}
proc report_utilization {args} {
 set fd [open [argument $args -file] w]
 puts $fd {| Site Type | Used | Fixed | Prohibited | Available | Util% |
| Slice LUTs | 610 | 0 | 0 | 53200 | 1.15 |
| Slice Registers | 544 | 0 | 0 | 106400 | 0.51 |
| Slice | 235 | 0 | 0 | 13300 | 1.77 |
| LUT as Logic | 598 | 0 | 0 | 53200 | 1.12 |
| Block RAM Tile | 0 | 0 | 0 | 140 | 0.00 |
| DSPs | 1 | 0 | 0 | 220 | 0.45 |
| F7 Muxes | 0 | 0 | 0 | 26600 | 0.00 |}
 close $fd
}
foreach name {write_checkpoint write_verilog} {proc $name {args} {set fd [open [lindex $args end] w];puts $fd {STUB DESIGN};close $fd}}
proc opt_design {} {lappend ::actions opt}
proc place_design {} {lappend ::actions place}
proc phys_opt_design {} {lappend ::actions phys}
proc route_design {} {lappend ::actions route;if {$::route_fails} {error "Injected route failure"}}
proc reset_mock {} {set ::project "";set ::actions {};set ::loaded_design {};set ::properties {};set ::constraint_texts {};set ::exec_count 0}
foreach module {core mac mac_accumulate residual relu pooling general_average_pooling} {
 reset_mock
 set cfg [fpga::config $module]
 fpga::test $module
 if {[dict get $properties [list sim_1 top]] ne [dict get $cfg tb]} {error "Wrong module TB"}
 if {$loaded_design ne [dict get $cfg rtl_files]} {error "Wrong module sources"}
 if {$exec_count} {error "Functional test unexpectedly requires Python"}
 reset_mock
 set dir [fpga::analyze $module]
 if {[argument $last_synth -top] ne [dict get $cfg top]} {error "Wrong analysis top"}
 foreach path {timing/post_synth.rpt timing/post_route.rpt utilization/post_synth.rpt utilization/post_route.rpt} {
  if {![file isfile [file join $dir $path]]} {error "Missing report $path"}
 }
 if {$exec_count} {error "Reports unexpectedly require Python"}
 puts "PASS $module: independent TB and post-synth/post-route reports without Python"
 fpga::images $module
 if {!$exec_count} {error "PNG conversion not invoked"}
 puts "PASS $module: PNG conversion is a separate optional step"
}
reset_mock
set first [fpga::analyze relu]
reset_mock
set route_fails 1
if {![catch {fpga::analyze relu} msg] || $msg ne "Injected route failure"} {error "Failure not propagated"}
set route_fails 0
set fd [open [file join $fpga::root build analysis relu latest.txt] r];set latest [string trim [read $fd]];close $fd
if {$latest ne $first} {error "Failed run replaced completed results"}
puts "PASS failed run preserves latest completed results"
set project user_project
if {![catch {fpga::test core} msg] || ![string match "Save/close*" $msg]} {error "Open project not protected"}
puts "PASS open project protected"
if {![catch {fpga::finish} msg] || ![string match "Save/close*" $msg] || $project ne "user_project"} {error "Finish discarded user project"}
reset_mock
fpga::finish
fpga::sim tb_core
if {$exec_count} {error "Full model test unexpectedly requires Python"}
if {"log_wave" ni $actions || "add_wave" ni $actions} {error "Full model simulation must retain waveforms by default"}
set sim_options [dict get $properties [list sim_1 -dict]]
if {![string match *vectors_dir=* $sim_options] || ![string match *weight_path=* $sim_options]} {error "Missing full model plusargs"}
fpga::finish
if {$project ne "" || [lsearch -exact $actions close_sim]<0} {error "Finish did not close generated simulation"}
fpga::synth relu
fpga::finish
if {$project ne ""} {error "Finish did not close generated synthesis project"}
puts "PASS full-model static directory fixture, synth, and safe finish"
reset_mock
set report_keys {}
rename exec workflow_stub_exec
proc exec {args} {
 if {[file tail [lindex $args 2]] eq "report_tools.py"} {
  if {[lindex $args 3] ne "key"} {error "Expected to fingerprint report inputs"}
  set inputs [lrange $args 4 end]
  if {![dict exists $::report_keys $inputs]} {
   dict set ::report_keys $inputs [dict size $::report_keys]
  }
  return "$::report_version-[dict get $::report_keys $inputs]"
 }
 if {[file tail [lindex $args 2]] ne "check_snr.py"} {return [workflow_stub_exec {*}$args]}
 if {[lindex $args 0] ne $::report_python || [lindex $args 1] ne "-E" || [lsearch -exact $::actions run] < 0} {
  error "SNR checker called before simulation or with wrong output directory"
 }
 set run [argument $args --run]
 foreach name {latency.txt results.json scoreboard_results.txt} {
  set fd [open [file join $run $name] w]
  puts $fd "STUB $name"
  close $fd
 }
 return {STUB SNR}
}
set report_python {C:/Python Install/python.exe}
fpga::analyze core
fpga::finish
if {"close_sim" in $actions} {error "Closing an analysis project must not close a simulation"}
reset_mock
set report_path [fpga::report 20.0]
if {$report_path ne [file join $fpga::root reports core_report.html]} {error "Wrong HTML report destination"}
set html [fpga::read_text_file $report_path]
foreach label {{Design Timing Summary} {<h3>Setup</h3>} {<h3>Hold</h3>} {<h3>Pulse Width</h3>} {VIOLATED} {LUT as Logic} {(13300)} {<td>235</td>}} {
 if {[string first $label $html] < 0} {error "Missing HTML report item $label"}
}
if {"simulate" in $actions || $exec_count || [regexp {SNR|STUB TIMING DETAILS|F7 Muxes} $html]} {
 error "Implementation report must skip simulation, Python and SNR"
}
if {![string match {* -period 20.0 *} [lindex $constraint_texts end]]} {error "Report did not forward period"}
if {$project ne "design_core" || "close_project" in $actions} {
 error "Report must leave the analysis project open"
}
fpga::finish
if {$project ne ""} {error "Finish did not close the report analysis project"}
reset_mock
set sim_report [fpga::report_sim $report_python xsim]
set fd [open $sim_report r];set sim_text [read $fd];close $fd
foreach section {{SNR (dB)} {Latency (ns and cycles)}} {
 if {[string first $section $sim_text] < 0} {error "Missing simulation report section $section"}
}
if {"simulate" ni $actions || "synth" in $actions || "log_wave" in $actions || "add_wave" in $actions} {
 error "Simulation report must run without implementation or waveforms"
}
reset_mock
fpga::report_sim $report_python xsim
if {"simulate" in $actions || "synth" in $actions} {error "Simulation cache hit repeated a measurement"}
rename exec {}
rename workflow_stub_exec exec
if {$empty_project_queries} {error "current_project queried with no projects open"}
puts "PASS analyze -> finish -> report without querying an empty current project"
puts "PASS separate implementation and simulation reports with simulation cache reuse"
# Custom source/config reuse remains supported.
if {[llength $argv]} {
 set fpga::root [file normalize [lindex $argv 0]]
 reset_mock
 fpga::sim tb_foreign
 foreach {name values} [list design $loaded_design tests [fpga::manifest tb_foreign] includes [dict get $properties [list sources_1 include_dirs]] defines [dict get $properties [list sources_1 verilog_define]]] {
  set fd [open [file join $fpga::root "$name.txt"] w];foreach value $values {puts $fd $value};close $fd
 }
 if {[dict get $properties [list sources_1 top]] ne "gain_block" || $exec_count} {error "Foreign design configuration ignored"}
 reset_mock
 fpga::analyze
 if {[argument $last_synth -top] ne "gain_block" || [argument $last_synth -part] ne "xc7a35tcpg236-1" || $exec_count} {error "Foreign analysis configuration ignored"}
 puts "PASS foreign RTL reuse without Python"
}
puts "PASS generic workflow tests (Vivado APIs stubbed)"
