# run_sim_d3.tcl - End-to-end D3 (parallel) simulation: pixel in → 2D DCT → compare golden
# Usage: vsim -c -do run_sim_d3.tcl

quit -sim

if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

# Compile RTL (leaf modules first)
vlog -sv ../rtl/mac_unit.sv
vlog -sv ../rtl/coefficient_rom.sv
vlog -sv ../rtl/dct_1d_engine.sv
vlog -sv ../rtl/pixel_block_buffer.sv
vlog -sv ../rtl/transpose_buffer.sv
vlog -sv ../rtl/quantizer.sv
vlog -sv ../rtl/output_buffer.sv
vlog -sv ../rtl/top_dct_accelerator.sv

# Compile testbench
vlog -sv ../tb/tb_dct_top.sv

# Copy test data files into the sim directory (ModelSim reads from CWD)
file copy -force ../matlab/outputs/test_vectors.hex .
file copy -force ../matlab/outputs/golden_coeffs_fixed.txt .

# Elaborate with D3 parameters: PARALLEL=1, PIPELINE_STAGES=1
vsim -t 1ps -L work work.tb_dct_top -voptargs="+acc" \
    -GPARALLEL=1 -GPIPELINE_STAGES=1
log -r /*
run -all

quit -f
