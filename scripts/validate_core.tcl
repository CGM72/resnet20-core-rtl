# GUI helper. Sourcing registers commands only; no project is modified yet.
# core_sim::launch tb_modules     -- tb/tb_modules/tb_modules.sv
# core_sim::launch tb_core_stream -- tb/tb_core_stream/tb_core_stream.sv
# core_sim::launch tb_core        -- tb/tb_core/tb_core.sv
# Optional Python executable: core_sim::launch tb_modules {C:/Python312/python.exe}
namespace eval core_sim {
    variable root [file normalize [file join [file dirname [info script]] ..]]
    proc launch {bench {python_exe python}} {
        variable root
        # Some Vivado versions still throw Coretcl 2-88 for current_project -quiet
        # when no project is open. That is the normal starting state for this helper.
        set open_project ""
        catch {set open_project [current_project -quiet]}
        if {$open_project ne ""} {
            error "Save/close the current project first. For an open simulation: close_sim -force; close_project"
        }
        # Accept the real TB module name or its .sv filename; no modules/stream/core aliases.
        set top [file rootname [file tail $bench]]
        set benches {tb_modules tb_core_stream tb_core}
        if {[lsearch -exact $benches $top] < 0} {
            error "Use an actual testbench name: $benches (or the matching .sv filename)"
        }
        set tb_dir [file join $root tb $top]
        set manifest [file join $tb_dir "$top.f"]
        set tb_source [file join $tb_dir "$top.sv"]
        if {![file isfile $manifest] || ![file isfile $tb_source]} {
            error "Missing matching TB files: $manifest / $tb_source. Update the complete package."
        }
        # Validate every source before creating a project, so bad paths do not leave one open.
        set fd [open $manifest r]
        set listing [read $fd]
        close $fd
        set sources {}
        foreach item [split $listing "\n"] {
            set item [string trim $item]
            if {$item eq "" || [string index $item 0] eq "#" || [string match {//*} $item]} {continue}
            set source [file normalize [file join $tb_dir $item]]
            if {![file isfile $source]} {error "Missing source $source"}
            lappend sources $source
        }
        if {[lsearch -exact $sources $tb_source] < 0} {
            error "$manifest must include its matching source $tb_source"
        }
        set project_dir [file join $root build vivado $top]
        file mkdir $project_dir
        set options "-onfinish stop"
        if {$top eq "tb_modules"} {
            set vectors [file join $project_dir unit_vectors.txt]
            puts [exec $python_exe [file join $root verification core golden_ref generate_unit_vectors.py] --out $vectors]
            append options " -testplusarg \"vectors_path=$vectors\""
        } elseif {$top eq "tb_core"} {
            set vectors [file join $project_dir vectors]
            puts [exec $python_exe [file join $root verification core golden_ref generate_resnet20_core.py] --out $vectors]
            append options " -testplusarg \"vectors_dir=$vectors\""
            append options " -testplusarg \"weight_path=[file join $root verification resnet20 weight.bin]\""
        }
        puts "TB=$top; source=$tb_source; manifest=$manifest"
        create_project -force sim_$top $project_dir -part xc7z020clg484-1
        set_property target_language Verilog [current_project]
        foreach source $sources {
            if {[file dirname $source] eq [file join $root rtl compute]} {
                add_files -fileset sources_1 -norecurse [list $source]
            } else {
                add_files -fileset sim_1 -norecurse [list $source]
            }
        }
        set_property top $top [get_filesets sim_1]
        set includes [list $tb_dir]
        if {$top eq "tb_core"} {lappend includes [file join $tb_dir include]}
        set_property include_dirs $includes [get_filesets sim_1]
        set_property xsim.elaborate.debug_level all [get_filesets sim_1]
        set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
        # -dict prevents a leading '-onfinish ...' value being parsed as a set_property option.
        set_property -dict [list xsim.simulate.xsim.more_options $options] [get_filesets sim_1]
        update_compile_order -fileset sources_1
        update_compile_order -fileset sim_1
        launch_simulation -simset sim_1 -mode behavioral
        log_wave -r /$top/*
        add_wave /$top/*
        if {$top ne "tb_modules"} {
            add_wave /$top/dut/*
            add_wave /$top/dut/u_mac/*
        }
        run all
    }
}
