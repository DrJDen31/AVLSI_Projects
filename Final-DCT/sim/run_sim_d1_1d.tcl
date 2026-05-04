# run_sim_d1_1d.tcl - Unit test D1 engine with tb_dct_1d
quit -sim

if {[file exists work]} { vdel -lib work -all }
vlib work
vmap work work

vlog -sv ../rtl/mac_unit.sv
vlog -sv ../rtl/coefficient_rom.sv
vlog -sv ../rtl/dct_1d_engine.sv
vlog -sv ../tb/tb_dct_1d.sv

# Default PIPELINE_STAGES=1 for D1
vsim -t 1ps -L work work.tb_dct_1d -voptargs="+acc"

run -all
quit -f
