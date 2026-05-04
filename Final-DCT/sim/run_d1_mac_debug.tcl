# run_d1_mac_debug.tcl - Trace MAC signals for D1 unit test
quit -sim

if {[file exists work]} { vdel -lib work -all }
vlib work
vmap work work

vlog -sv ../rtl/mac_unit.sv
vlog -sv ../rtl/coefficient_rom.sv
vlog -sv ../rtl/dct_1d_engine.sv
vlog -sv ../tb/tb_dct_1d.sv

vsim -t 1ps -L work work.tb_dct_1d -voptargs="+acc"

# Monitor MAC accumulator
run 50ns
echo "=== After reset ==="
echo "state = [examine sim:/tb_dct_1d/dut/state]"

# Run until S_COMPUTE starts
run 150ns
echo "=== In compute ==="
echo "state = [examine sim:/tb_dct_1d/dut/state]"
echo "phase = [examine -decimal sim:/tb_dct_1d/dut/phase]"
echo "k_idx = [examine -decimal sim:/tb_dct_1d/dut/k_idx]"
echo "mac_clr = [examine sim:/tb_dct_1d/dut/mac_clr]"
echo "mac_en = [examine sim:/tb_dct_1d/dut/mac_en]"
echo "mac_data = [examine -decimal sim:/tb_dct_1d/dut/mac_data]"
echo "mac_coeff = [examine -decimal sim:/tb_dct_1d/dut/mac_coeff]"
echo "mac_accum = [examine -decimal sim:/tb_dct_1d/dut/mac_accum]"
echo "rom_addr = [examine -decimal sim:/tb_dct_1d/dut/rom_addr]"
echo "rom_data = [examine -decimal sim:/tb_dct_1d/dut/rom_data]"
echo "x_reg[0] = [examine -decimal sim:/tb_dct_1d/dut/x_reg(0)]"
echo "x_reg[1] = [examine -decimal sim:/tb_dct_1d/dut/x_reg(1)]"

# Run one more cycle
run 10ns
echo "=== One cycle later ==="
echo "phase = [examine -decimal sim:/tb_dct_1d/dut/phase]"
echo "mac_en = [examine sim:/tb_dct_1d/dut/mac_en]"
echo "mac_data = [examine -decimal sim:/tb_dct_1d/dut/mac_data]"
echo "mac_coeff = [examine -decimal sim:/tb_dct_1d/dut/mac_coeff]"
echo "mac_accum = [examine -decimal sim:/tb_dct_1d/dut/mac_accum]"

quit -f
