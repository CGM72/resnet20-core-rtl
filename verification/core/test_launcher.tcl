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
    set ::created_args $args
    set ::test_project [lindex $args 1]
}
rename exec launcher_test_system_exec
proc exec {args} {
    if {![file isfile [lindex $args 1]]} {error "Missing fixture generator"}
    return "Fixture execution stub: launcher regression only"
}
proc set_property {args} {
    if {[lindex $args 0] eq "top"} {set ::selected_top [lindex $args 1]}
}
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
    foreach top {tb_modules tb_core_stream tb_core} {
        foreach argument [list $top "$top.sv"] {
            set test_project ""
            set create_count 0
            set run_count 0
            set selected_top ""
            if {[catch {core_sim::launch $argument} message]} {
                error "FAIL closed/$mode/$argument: $message"
            }
            if {$create_count != 1 || $run_count != 1 || $selected_top ne $top} {
                error "FAIL expected one matching project/top/simulation: $argument"
            }
            if {[lindex $created_args 1] ne "sim_$top" || [file tail [lindex $created_args 2]] ne $top} {
                error "FAIL project name/directory mismatch: $created_args"
            }
            puts "PASS: closed/$mode/$argument matches file, module, manifest, project and sim top"
        }
    }
}
set test_project existing_user_project
set create_count 0
set run_count 0
if {![catch {core_sim::launch tb_modules} message]} {error "FAIL existing project not protected"}
if {![string match "Save/close*" $message] || $create_count || $run_count} {
    error "FAIL existing project changed or wrong error: $message"
}
puts "PASS: open project rejected before any creation or simulation"
# An old alias must fail with real TB names, without creating a project.
set test_project ""
if {![catch {core_sim::launch modules} message] || ![string match "Use an actual testbench name:*" $message]} {
    error "FAIL old alias did not explain the actual TB names"
}
if {$create_count || $run_count} {error "FAIL invalid TB changed project state"}
puts "PASS: obsolete alias rejected with matching TB names"
# A partial package must fail before any project creation.
set saved_root $core_sim::root
set core_sim::root [file join $saved_root build missing_package_for_test]
if {![catch {core_sim::launch tb_modules} message] || ![string match "Missing matching TB files:*" $message]} {
    error "FAIL missing layout not detected"
}
set core_sim::root $saved_root
if {$create_count || $run_count} {error "FAIL missing files left a project open"}
puts "PASS: missing TB files rejected before project creation"
puts "PASS: launcher filename/project regression (Vivado APIs stubbed)"
