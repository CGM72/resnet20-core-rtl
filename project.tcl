# Edit this file when changing the design. All paths are relative to the repository root.
namespace eval ::fpga_project {
    variable settings [dict create \
        part xc7z020clg484-1 \
        top core \
        clock_port clk \
        period_ns 10.0 \
        python auto \
        rtl_files {
            rtl/compute/mac.v
            rtl/compute/conv.v
            rtl/compute/residual.v
            rtl/compute/relu.v
            rtl/compute/pooling.v
            rtl/compute/general_average_pooling.v
            rtl/compute/core.v
        } \
        include_dirs {} \
        defines {} \
        xdc_files {}]

    # A profile selects the synthesis top and its independent TB.
    variable targets [dict create \
        core [dict create top core rtl_files [dict get $settings rtl_files] tb tb_core_stream] \
        mac [dict create top mac rtl_files {rtl/compute/mac.v} tb tb_mac] \
        mac_accumulate [dict create top mac_accumulate rtl_files {rtl/compute/mac.v} tb tb_mac] \
        residual [dict create top residual rtl_files {rtl/compute/residual.v} tb tb_residual] \
        relu [dict create top relu rtl_files {rtl/compute/relu.v} tb tb_relu] \
        pooling [dict create top pooling rtl_files {rtl/compute/pooling.v} tb tb_pooling] \
        general_average_pooling [dict create top general_average_pooling rtl_files {rtl/compute/general_average_pooling.v} tb tb_general_average_pooling]]
    variable fixtures [dict create \
        tb_modules [dict create files [dict create vectors_path tb/common/unit_vectors.txt]] \
        tb_core [dict create files [dict create vectors_dir tb/tb_core/vectors weight_path verification/resnet20/weight.bin]]]
    foreach name {tb_mac tb_residual tb_relu tb_pooling tb_general_average_pooling} {
        dict set fixtures $name [dict create files [dict create vectors_path tb/common/unit_vectors.txt]]
    }
}
