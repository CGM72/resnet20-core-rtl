# GUI helper. Sourcing registers commands only; no project is modified yet.
# core_sim::launch modules   -- all actual arithmetic modules
# core_sim::launch stream    -- core skip/pipeline/reset protocol
# core_sim::launch core      -- attached full ResNet-20 fixture
# Optional Python executable: core_sim::launch modules {C:/Python312/python.exe}
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
        switch -- $bench {
            modules {
                set top tb_modules
                set manifest [file join $root tb tb_modules tb_modules.f]
            }
            stream {
                set top tb_core_stream
                set manifest [file join $root tb tb_core_stream.f]
            }
            core {
                set top tb_core
                set manifest [file join $root tb tb_core tb_core.f]
            }
            default {error "Choose modules, stream, or core"}
        }
        set project_dir [file join $root build vivado $top]
        file mkdir $project_dir
        set options "-onfinish stop"
        if {$bench eq "modules"} {
            set vectors [file join $project_dir unit_vectors.txt]
            puts [exec $python_exe [file join $root verification core golden_ref generate_unit_vectors.py] --out $vectors]
            append options " -testplusarg \"vectors_path=$vectors\""
        } elseif {$bench eq "core"} {
            set vectors [file join $project_dir vectors]
            puts [exec $python_exe [file join $root verification core golden_ref generate_resnet20_core.py] --out $vectors]
            append options " -testplusarg \"vectors_dir=$vectors\""
            append options " -testplusarg \"weight_path=[file join $root verification resnet20 weight.bin]\""
        }
        create_project -force sim_$top $project_dir -part xc7z020clg484-1
        set_property target_language Verilog [current_project]
        set fd [open $manifest r]
        set listing [read $fd]
        close $fd
        foreach item [split $listing "\n"] {
            set item [string trim $item]
            if {$item eq "" || [string index $item 0] eq "#"} {continue}
            set source [file normalize [file join [file dirname $manifest] $item]]
            if {![file isfile $source]} {error "Missing source $source"}
            if {[file dirname $source] eq [file join $root rtl compute]} {
                add_files -fileset sources_1 -norecurse [list $source]
            } else {
                add_files -fileset sim_1 -norecurse [list $source]
            }
        }
        set_property top $top [get_filesets sim_1]
        set_property include_dirs [list [file join $root tb tb_core include]] [get_filesets sim_1]
        set_property xsim.elaborate.debug_level all [get_filesets sim_1]
        set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
        # -dict prevents a leading '-onfinish ...' value being parsed as a set_property option.
        set_property -dict [list xsim.simulate.xsim.more_options $options] [get_filesets sim_1]
        update_compile_order -fileset sources_1
        update_compile_order -fileset sim_1
        launch_simulation -simset sim_1 -mode behavioral
        log_wave -r /$top/*
        add_wave /$top/*
        if {$bench ne "modules"} {
            add_wave /$top/dut/*
            add_wave /$top/dut/u_mac/*
        }
        run all
    }
}
