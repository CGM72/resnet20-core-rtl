# Source in Vivado or run: tclsh verification/check_paths.tcl
source [file normalize [file join [file dirname [info script]] .. scripts vivado.tcl]]
set cfg [fpga::config]
puts "PASS design: top=[dict get $cfg top], [llength [dict get $cfg rtl_files]] RTL files"
foreach directory [glob -nocomplain -type d [file join $fpga::root tb *]] {
    set name [file tail $directory]
    if {![file isfile [file join $directory "$name.f"]]} {continue}
    set sources [fpga::manifest $name]
    set fd [open [file join $directory "$name.sv"] r]
    set text [read $fd]
    close $fd
    if {![regexp "\\mmodule\\s+$name\\M" $text]} {error "TB module/file name mismatch: $name"}
    puts "PASS testbench: $name ([llength $sources] test sources)"
}
