# Regression for launcher project-state handling. Run with tclsh; this is not XSim.
source [file normalize [file join [file dirname [info script]] .. .. scripts validate_core.tcl]]
set test_project ""
set no_project_errors 1
set create_count 0
set run_count 0
proc current_project {args} {
    if {$::test_project ne ""} {return $::test_project}
    if {$::no_project_errors} {
        return -code error {ERROR: [Coretcl 2-88] No projects are currently open.}
    }
    return ""
}
proc create_project {args} {
    incr ::create_count
    set ::test_project [lindex $args 1]
}
rename exec launcher_test_system_exec
proc exec {args} {
    if {![file isfile [lindex $args 1]]} {error "Missing fixture generator"}
    return "Fixture execution stub: launcher regression only"
}
proc set_property {args} {}
proc get_filesets {args} {return sim_1}
proc add_files {args} {
    foreach file [lindex $args end] {
        if {![file isfile $file]} {error "Missing source $file"}
    }
}
proc update_compile_order {args} {}
proc launch_simulation {args} {}
proc log_wave {args} {}
proc add_wave {args} {}
proc run {args} {
    if {$args ne "all"} {error "Expected run all"}
    incr ::run_count
}
foreach mode {error empty} {
    set no_project_errors [expr {$mode eq "error"}]
    foreach bench {modules stream core} {
        set test_project ""
        set create_count 0
        set run_count 0
        if {[catch {core_sim::launch $bench} message]} {
            error "FAIL closed/$mode/$bench: $message"
        }
        if {$create_count != 1 || $run_count != 1} {
            error "FAIL expected one project creation and simulation dispatch"
        }
        puts "PASS: closed/$mode/$bench creates project and dispatches simulation"
    }
}
set test_project existing_user_project
set create_count 0
set run_count 0
if {![catch {core_sim::launch modules} message]} {error "FAIL existing project not protected"}
if {![string match "Save/close*" $message] || $create_count || $run_count} {
    error "FAIL existing project changed or wrong error: $message"
}
puts "PASS: open project rejected before any creation or simulation"
puts "PASS: launcher project-state regression (Vivado APIs stubbed)"
