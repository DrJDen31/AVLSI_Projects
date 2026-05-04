# run_sim_d3_1d.tcl - Unit test D3 engine with tb_dct_1d
quit -sim

if {[file exists work]} { vdel -lib work -all }
vlib work
vmap work work

vlog -sv ../rtl/mac_unit.sv
vlog -sv ../rtl/coefficient_rom.sv
vlog -sv ../rtl/dct_1d_engine.sv
vlog -sv ../tb/tb_dct_1d.sv

# Override PARALLEL=1, PIPELINE_STAGES=1 for D3
vsim -t 1ps -L work work.tb_dct_1d -voptargs="+acc" \
    -GPARALLEL=1 -GPIPELINE_STAGES=1

run -all
quit -f
