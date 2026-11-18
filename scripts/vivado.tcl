# One entry point: source scripts/vivado.tcl
# fpga::sim tb_core_stream | fpga::analyze | fpga::synth
namespace eval fpga {
    variable root [file normalize [file join [file dirname [info script]] ..]]

    proc absolute {path} {
        variable root
        return [file normalize [file join $root $path]]
    }

    proc config {} {
        variable root
        namespace eval ::fpga_project {variable settings {}; variable fixtures {}}
        source [file join $root project.tcl]
        set cfg $::fpga_project::settings
        foreach key {part top period_ns rtl_files} {
            if {![dict exists $cfg $key] || [dict get $cfg $key] eq ""} {error "project.tcl: missing $key"}
        }
        foreach {key default} {python auto clock_port {} include_dirs {} defines {} xdc_files {}} {
            if {![dict exists $cfg $key]} {dict set cfg $key $default}
        }
        if {![regexp {^[A-Za-z_][A-Za-z0-9_$]*$} [dict get $cfg top]]} {error "Invalid top module name"}
        foreach key {rtl_files xdc_files include_dirs} {
            set paths {}
            foreach path [dict get $cfg $key] {
                set path [absolute $path]
                if {$key eq "include_dirs"} {
                    if {![file isdirectory $path]} {error "Missing include directory $path"}
                } elseif {![file isfile $path]} {error "Missing $key file $path"}
                lappend paths $path
            }
            dict set cfg $key $paths
        }
        dict set cfg fixtures $::fpga_project::fixtures
        return $cfg
    }

    # A Tcl command prefix is a list: one executable path, or e.g. {py -3}.
    # Probe the interpreter, not just PATH entries (Windows Store aliases are not runtimes).
    proc python_command {{requested auto}} {
        set candidates {}
        if {$requested in {"" auto python}} {
            set candidates [list [list python] [list python3] [list py -3]]
            foreach key {LOCALAPPDATA ProgramFiles ProgramFiles(x86)} {
                if {![info exists ::env($key)]} {continue}
                set base $::env($key)
                if {$key eq "LOCALAPPDATA"} {set base [file join $base Programs Python]}
                foreach path [lsort -decreasing -dictionary [glob -nocomplain -directory $base Python*/python.exe]] {
                    lappend candidates [list $path]
                }
            }
        } elseif {[file exists $requested] || [file pathtype $requested] eq "absolute" ||
                  [string match -nocase *.exe $requested] || [regexp {[/\\]} $requested]} {
            set candidates [list [list $requested]]
        } else {
            # Allows an explicit launcher prefix such as {py -3.12}.
            if {[catch {llength $requested}]} {error "Invalid Python command/path: $requested"}
            set candidates [list $requested]
        }
        set probe {import sys; sys.exit(1) if sys.version_info < (3, 10) else print("FPGA_PYTHON_OK")}
        foreach command $candidates {
            set executable [lindex $command 0]
            set resolved [auto_execok $executable]
            set resolved_path [string map {\\ /} [lindex $resolved 0]]
            if {[string match -nocase */Microsoft/WindowsApps/python*.exe $resolved_path]} {continue}
            if {![catch {exec {*}$command -c $probe 2>@1} output] &&
                [lsearch -exact [split [string trim $output] "\n"] FPGA_PYTHON_OK] >= 0} {
                puts "Python: $command"
                return $command
            }
        }
        error {Python 3.10+ was not found. Set python {C:/.../python.exe} in project.tcl, or run fpga::analyze 10.0 {C:/.../python.exe}. Install Python if no interpreter is installed.}
    }

    proc require_closed {} {
        # Vivado may throw Coretcl 2-88 even with -quiet; no project is a valid starting state.
        set project ""
        catch {set project [current_project -quiet]}
        if {$project ne ""} {error "Save/close the current project first: close_sim -force; close_project"}
    }

    proc period {value} {
        if {![string is double -strict $value] ||
            [catch {expr {double($value) > 0 && double($value) < Inf}} valid] || !$valid} {
            error "Clock period must be a positive finite value in ns"
        }
        return $value
    }

    proc manifest {tb} {
        variable root
        if {![regexp {^[A-Za-z_][A-Za-z0-9_$]*$} $tb]} {error "Use the actual TB name or its .sv filename"}
        set directory [file join $root tb $tb]
        set list_file [file join $directory "$tb.f"]
        set source [file join $directory "$tb.sv"]
        if {![file isfile $list_file] || ![file isfile $source]} {error "Missing matching TB files: $list_file / $source"}
        set fd [open $list_file r]
        set contents [read $fd]
        close $fd
        set sources {}
        foreach line [split $contents "\n"] {
            set line [string trim $line]
            if {$line eq "" || [string index $line 0] eq "#" || [string match {//*} $line]} {continue}
            set file [file normalize [file join $directory $line]]
            if {![file isfile $file]} {error "Missing TB source $file"}
            lappend sources $file
        }
        if {[lsearch -exact $sources $source] < 0} {error "$list_file must include $source"}
        return $sources
    }

    proc sim {testbench {python_exe ""}} {
        variable root
        require_closed
        set cfg [config]
        set tb [file rootname [file tail $testbench]]
        set tb_sources [manifest $tb]
        set directory [file join $root build sim $tb]
        set tb_dir [file join $root tb $tb]
        file mkdir $directory
        if {$python_exe eq ""} {set python_exe [dict get $cfg python]}
        set options "-onfinish stop"
        if {[dict exists $cfg fixtures $tb]} {
            set python_exe [python_command $python_exe]
            set fixture [dict get $cfg fixtures $tb]
            set generator [absolute [dict get $fixture generator]]
            if {![file isfile $generator]} {error "Missing fixture generator $generator"}
            set output [file join $directory [dict get $fixture output]]
            puts [exec {*}$python_exe $generator --out $output]
            append options " -testplusarg \"[dict get $fixture argument]=$output\""
            if {[dict exists $fixture files]} {
                dict for {argument path} [dict get $fixture files] {
                    set path [absolute $path]
                    if {![file isfile $path]} {error "Missing fixture data $path"}
                    append options " -testplusarg \"$argument=$path\""
                }
            }
        }
        puts "Design top=[dict get $cfg top]; TB=$tb"
        create_project -force "sim_$tb" $directory -part [dict get $cfg part]
        set_property target_language Verilog [current_project]
        add_files -fileset sources_1 -norecurse [dict get $cfg rtl_files]
        add_files -fileset sim_1 -norecurse $tb_sources
        set_property top [dict get $cfg top] [get_filesets sources_1]
        set_property top $tb [get_filesets sim_1]
        set includes [dict get $cfg include_dirs]
        set_property include_dirs $includes [get_filesets sources_1]
        lappend includes $tb_dir
        if {[file isdirectory [file join $tb_dir include]]} {lappend includes [file join $tb_dir include]}
        set_property include_dirs $includes [get_filesets sim_1]
        foreach fileset {sources_1 sim_1} {
            set_property verilog_define [dict get $cfg defines] [get_filesets $fileset]
            update_compile_order -fileset $fileset
        }
        set_property xsim.elaborate.debug_level all [get_filesets sim_1]
        set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
        set_property -dict [list xsim.simulate.xsim.more_options $options] [get_filesets sim_1]
        launch_simulation -simset sim_1 -mode behavioral
        log_wave -r /$tb/*
        add_wave /$tb/*
        run all
    }

    proc start_design {cfg directory clock_period} {
        file mkdir $directory
        set clock_file ""
        if {[dict get $cfg clock_port] ne ""} {
            set clock_file [file join $directory clock.xdc]
            set fd [open $clock_file w]
            puts $fd [format {create_clock -name design_clk -period %s [get_ports %s]} \
                $clock_period [list [dict get $cfg clock_port]]]
            close $fd
        }
        create_project -in_memory "design_[dict get $cfg top]" -part [dict get $cfg part]
        set options [list -sv]
        if {[llength [dict get $cfg include_dirs]]} {lappend options -include_dirs [dict get $cfg include_dirs]}
        if {[llength [dict get $cfg defines]]} {lappend options -define [dict get $cfg defines]}
        foreach source [dict get $cfg rtl_files] {read_verilog {*}$options $source}
        if {$clock_file ne ""} {read_xdc $clock_file}
        foreach xdc [dict get $cfg xdc_files] {read_xdc $xdc}
        synth_design -top [dict get $cfg top] -part [dict get $cfg part] -mode out_of_context
    }

    proc synth {{clock_period ""}} {
        variable root
        require_closed
        set cfg [config]
        if {$clock_period eq ""} {set clock_period [dict get $cfg period_ns]}
        period $clock_period
        set top [dict get $cfg top]
        set directory [file join $root build synth $top]
        start_design $cfg $directory $clock_period
        report_utilization -file [file join $directory utilization.rpt]
        report_timing_summary -delay_type min_max -report_unconstrained -file [file join $directory timing.rpt]
        write_checkpoint -force [file join $directory "$top.dcp"]
        write_verilog -mode funcsim -force [file join $directory "${top}_funcsim.v"]
        puts "Synthesis results: $directory"
        return $directory
    }

    proc reports {directory stage python_exe} {
        variable root
        set timing [file join $directory timing]
        set utilization [file join $directory utilization]
        report_timing_summary -delay_type min_max -report_unconstrained \
            -name timing_$stage -file [file join $timing "$stage.rpt"]
        report_timing -delay_type max -max_paths 10 -file [file join $timing "${stage}_setup_paths.rpt"]
        report_timing -delay_type min -max_paths 10 -file [file join $timing "${stage}_hold_paths.rpt"]
        check_timing -verbose -file [file join $timing "${stage}_check_timing.rpt"]
        report_utilization -name utilization_$stage -file [file join $utilization "$stage.rpt"]
        report_utilization -hierarchical -file [file join $utilization "${stage}_hierarchical.rpt"]
        puts [exec {*}$python_exe [file join $root scripts export_analysis.py] export --results $directory --stage $stage]
    }

    proc analyze {{clock_period ""} {python_exe ""}} {
        variable root
        require_closed
        set cfg [config]
        if {$clock_period eq ""} {set clock_period [dict get $cfg period_ns]}
        period $clock_period
        if {$python_exe eq ""} {set python_exe [dict get $cfg python]}
        set python_exe [python_command $python_exe]
        puts [exec {*}$python_exe [file join $root scripts export_analysis.py] check --period $clock_period]
        set top [dict get $cfg top]
        set base [file join $root build analysis $top]
        set stamp [clock format [clock seconds] -format {run_%Y%m%d_%H%M%S}]
        set directory [file join $base $stamp]
        set suffix 1
        while {[file exists $directory]} {
            set directory [file join $base "${stamp}_$suffix"]
            incr suffix
        }
        foreach child {timing utilization checkpoints} {file mkdir [file join $directory $child]}
        set hash_sources [concat [dict get $cfg rtl_files] [dict get $cfg xdc_files] [list [file join $root project.tcl]]]
        puts [exec {*}$python_exe [file join $root scripts export_analysis.py] init \
            --results $directory --period $clock_period --top $top --part [dict get $cfg part] \
            --clock-port [dict get $cfg clock_port] --sources {*}$hash_sources \
            --include-dirs {*}[dict get $cfg include_dirs]]
        puts "Analysis results: $directory"
        if {[catch {
            start_design $cfg $directory $clock_period
            reports $directory post_synth $python_exe
            write_checkpoint -force [file join $directory checkpoints "${top}_post_synth.dcp"]
            opt_design
            place_design
            if {[dict get $cfg clock_port] ne "" || [llength [dict get $cfg xdc_files]]} {phys_opt_design}
            route_design
            report_route_status -file [file join $directory timing post_route_route_status.rpt]
            reports $directory post_route $python_exe
            report_drc -file [file join $directory timing post_route_drc.rpt]
            write_checkpoint -force [file join $directory checkpoints "${top}_post_route.dcp"]
        } message options]} {
            puts stderr "Analysis failed. Partial reports: $directory"
            return -options $options $message
        }
        set fd [open [file join $base latest.txt] w]
        puts $fd $directory
        close $fd
        puts "Timing PNG: [file join $directory timing post_route.png]"
        puts "Utilization PNG: [file join $directory utilization post_route.png]"
        return $directory
    }
}
