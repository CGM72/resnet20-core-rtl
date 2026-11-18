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
            rtl/compute/residual.v
            rtl/compute/relu.v
            rtl/compute/pooling.v
            rtl/compute/general_average_pooling.v
            rtl/compute/core.sv
        } \
        include_dirs {} \
        defines {} \
        xdc_files {}]

    # Only the supplied numeric tests need generated data. A new TB needs no entry here.
    variable fixtures [dict create \
        tb_modules [dict create \
            generator verification/core/golden_ref/generate_unit_vectors.py \
            output unit_vectors.txt argument vectors_path] \
        tb_core [dict create \
            generator verification/core/golden_ref/generate_resnet20_core.py \
            output vectors argument vectors_dir \
            files [dict create weight_path verification/resnet20/weight.bin]]]
}
