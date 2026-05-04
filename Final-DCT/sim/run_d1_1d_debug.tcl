# run_d1_1d_debug.tcl - Debug D1 1D test
quit -sim

if {[file exists work]} { vdel -lib work -all }
vlib work
vmap work work

vlog -sv ../rtl/mac_unit.sv
vlog -sv ../rtl/coefficient_rom.sv
vlog -sv ../rtl/dct_1d_engine.sv
vlog -sv ../tb/tb_dct_1d.sv

vsim -t 1ps -L work work.tb_dct_1d -voptargs="+acc"

# Check ROM values before running
run 0ns
echo "=== ROM check at time 0 ==="
echo "rom[0] = [examine -decimal sim:/tb_dct_1d/dut/gen_d1/u_rom/rom(0)]"
echo "data_out = [examine -decimal sim:/tb_dct_1d/dut/gen_d1/u_rom/data_out]"

run 1ns
echo "=== After 1ns ==="
echo "rom[0] = [examine -decimal sim:/tb_dct_1d/dut/gen_d1/u_rom/rom(0)]"
echo "data_out = [examine -decimal sim:/tb_dct_1d/dut/gen_d1/u_rom/data_out]"
echo "state = [examine sim:/tb_dct_1d/dut/gen_d1/state]"

run -all

quit -f
