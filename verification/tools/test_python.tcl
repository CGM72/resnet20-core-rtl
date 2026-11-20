# Interpreter discovery regression. External interpreter launches are simulated.
source [file normalize [file join [file dirname [info script]] .. .. scripts vivado.tcl]]
rename exec python_test_exec
rename auto_execok python_test_auto_execok
set mode python3
set seen {}
proc auto_execok {name} {
    if {$::mode eq "alias" && $name eq "python"} {
        return [list {C:/Users/test/AppData/Local/Microsoft/WindowsApps/python.exe}]
    }
    return [list $name]
}
proc exec {args} {
    set index [lsearch -exact $args -c]
    if {$index < 1 || [lindex $args [expr {$index-1}]] ne "-E"} {error "Expected an environment-independent version probe"}
    set prefix [lrange $args 0 [expr {$index-2}]]
    lappend ::seen $prefix
    switch -- $::mode {
        python3 - alias {
            if {$prefix eq "python3"} {return "FPGA_PYTHON_OK"}
        }
        py {
            if {$prefix eq "py -3"} {return "FPGA_PYTHON_OK"}
        }
        explicit {
            if {$prefix eq [list {C:/Program Files/Python/python.exe}]} {return "FPGA_PYTHON_OK"}
        }
        installed {
            if {[file tail [lindex $prefix 0]] eq "python.exe"} {return "FPGA_PYTHON_OK"}
        }
        none {}
        old {return "Python 3.9"}
    }
    error {couldn't execute Python: no such file or directory}
}
set command [fpga::python_command]
if {$command ne "python3"} {error "python3 fallback failed"}
puts "PASS fallback to python3 when python is unavailable"
set mode py
if {[fpga::python_command python] ne "py -3"} {error "py launcher prefix failed"}
puts "PASS Windows py -3 and legacy python setting fallback"
set mode explicit
if {[fpga::python_command {C:/Program Files/Python/python.exe}] ne [list {C:/Program Files/Python/python.exe}]} {error "Path split on spaces"}
puts "PASS explicit executable path with spaces remains one argument"
set mode alias
set seen {}
if {[fpga::python_command] ne "python3" || [lsearch -exact $seen python] >= 0} {error "Windows Store alias executed"}
puts "PASS Store command alias skipped"
set mode installed
set temporary [file join $fpga::root build python_test_local]
file mkdir [file join $temporary Programs Python Python312]
set fd [open [file join $temporary Programs Python Python312 python.exe] w];close $fd
set had_local [info exists ::env(LOCALAPPDATA)]
if {$had_local} {set saved_local $::env(LOCALAPPDATA)}
set ::env(LOCALAPPDATA) $temporary
set command [fpga::python_command]
if {[file tail [lindex $command 0]] ne "python.exe"} {error "Local install folder fallback failed"}
set managed [file join $temporary Python pythoncore-3.15-64 python.exe]
file mkdir [file dirname $managed]
set fd [open $managed w];close $fd
file delete [file join $temporary Programs Python Python312 python.exe]
if {[fpga::python_command] ne [list $managed]} {error "Python Install Manager runtime discovery failed"}
file delete $managed
puts "PASS Windows Python Install Manager runtime"
if {$had_local} {set ::env(LOCALAPPDATA) $saved_local} else {unset ::env(LOCALAPPDATA)}
puts "PASS standard Windows local installation folder"
foreach mode {none old} {
    if {![catch {fpga::python_command} message] || ![string match "Python 3.10+ was not found.*" $message]} {error "Missing/old interpreter not diagnosed"}
}
puts "PASS missing or old Python explains exact-path configuration"

# The installation helper must choose the same explicitly configured Python as analyze/sim.
set saved_root $fpga::root
set config_root [file join $saved_root build python_test_config]
file mkdir $config_root
set fd [open [file join $config_root dummy.sv] w];puts $fd {module dummy; endmodule};close $fd
set fd [open [file join $config_root project.tcl] w]
puts $fd {namespace eval ::fpga_project {variable settings [dict create part test_part top dummy clock_port clk period_ns 10 rtl_files {dummy.sv} python {C:/Program Files/Python/python.exe}]}}
close $fd
set fpga::root $config_root
set mode explicit
if {[fpga::python_command] ne [list {C:/Program Files/Python/python.exe}]} {error "No-argument helper ignored project.tcl Python"}
set fpga::root $saved_root
puts "PASS default helper honors project.tcl, matching Pillow install and analysis interpreter"
