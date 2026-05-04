# run_d1_xreg7.tcl - Direct check of x_reg[7]
quit -sim

if {[file exists work]} { vdel -lib work -all }
vlib work
vmap work work

vlog -sv ../rtl/mac_unit.sv
vlog -sv ../rtl/coefficient_rom.sv
vlog -sv ../rtl/dct_1d_engine.sv
vlog -sv ../tb/tb_dct_1d.sv

vsim -t 1ps -L work work.tb_dct_1d -voptargs="+acc"

run 200ns
echo "=== At 200ns ==="
echo "state = [examine sim:/tb_dct_1d/dut/state]"
echo "phase = [examine -unsigned sim:/tb_dct_1d/dut/phase]"
echo "x_reg[0] = [examine -decimal sim:/tb_dct_1d/dut/x_reg(0)]"
echo "x_reg[1] = [examine -decimal sim:/tb_dct_1d/dut/x_reg(1)]"
echo "x_reg[2] = [examine -decimal sim:/tb_dct_1d/dut/x_reg(2)]"
echo "x_reg[3] = [examine -decimal sim:/tb_dct_1d/dut/x_reg(3)]"
echo "x_reg[4] = [examine -decimal sim:/tb_dct_1d/dut/x_reg(4)]"
echo "x_reg[5] = [examine -decimal sim:/tb_dct_1d/dut/x_reg(5)]"
echo "x_reg[6] = [examine -decimal sim:/tb_dct_1d/dut/x_reg(6)]"
echo "x_reg[7] = [examine -decimal sim:/tb_dct_1d/dut/x_reg(7)]"
echo "mac_data = [examine -decimal sim:/tb_dct_1d/dut/mac_data]"
echo "mac_en = [examine sim:/tb_dct_1d/dut/mac_en]"

quit -f
