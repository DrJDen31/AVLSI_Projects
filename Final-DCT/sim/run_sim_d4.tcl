# run_sim_d4.tcl - Compile and run D4 (pipelined + parallel) end-to-end simulation
quit -sim

if {[file exists work]} { vdel -lib work -all }
vlib work
vmap work work

vlog -sv ../rtl/mac_unit.sv
vlog -sv ../rtl/coefficient_rom.sv
vlog -sv ../rtl/dct_1d_engine.sv
vlog -sv ../rtl/pixel_block_buffer.sv
vlog -sv ../rtl/transpose_buffer.sv
vlog -sv ../rtl/quantizer.sv
vlog -sv ../rtl/output_buffer.sv
vlog -sv ../rtl/top_dct_accelerator.sv
vlog -sv ../tb/tb_dct_top.sv

file copy -force ../matlab/outputs/test_vectors.hex .
file copy -force ../matlab/outputs/golden_coeffs_fixed.txt .

# Override PARALLEL=1 and PIPELINE_STAGES=4 for D4
vsim -t 1ps -L work work.tb_dct_top -voptargs="+acc" \
    -GPARALLEL=1 -GPIPELINE_STAGES=4

log -r /*
run -all

quit -f
