# run_sim.tcl - ModelSim batch driver: compile RTL + TB
# Usage: vsim -c -do run_sim.tcl

# Quit any existing simulation
quit -sim

# Create work library (if not already present)
if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

# Compile RTL (order matters: leaf modules first)
vlog -sv ../rtl/mac_unit.sv
vlog -sv ../rtl/coefficient_rom.sv
vlog -sv ../rtl/dct_1d_engine.sv
vlog -sv ../rtl/pixel_block_buffer.sv
vlog -sv ../rtl/transpose_buffer.sv
vlog -sv ../rtl/quantizer.sv
vlog -sv ../rtl/output_buffer.sv
vlog -sv ../rtl/top_dct_accelerator.sv

# Compile testbenches
vlog -sv ../tb/tb_coefficient_rom.sv
vlog -sv ../tb/tb_mac_unit.sv
vlog -sv ../tb/tb_transpose.sv
vlog -sv ../tb/tb_quantizer.sv
vlog -sv ../tb/tb_dct_1d.sv
vlog -sv ../tb/tb_dct_top.sv

# Copy test data files into the sim directory (ModelSim reads from CWD)
file copy -force ../matlab/outputs/test_vectors.hex .
file copy -force ../matlab/outputs/golden_coeffs_fixed.txt .

echo "Compilation complete. You can now run vsim on specific testbenches."
# Exit ModelSim (optional, but requested by prompt to just compile and not run vsim tb_dct_top)
quit -f
