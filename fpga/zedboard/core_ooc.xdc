# Core-only timing target. Board pin constraints belong to the future system top.
create_clock -name core_clk -period 10.000 [get_ports {clk}]
# Boundary I/O delays and reset release constraints must be defined by the system.
