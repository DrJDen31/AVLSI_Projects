# run_d1_rom_check.tcl - Check if D1 ROM values are loaded
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

vsim -t 1ps -L work work.tb_dct_top -voptargs="+acc"

# Check ROM values for row DCT engine
echo "=== D1 Row DCT ROM check ==="
echo "rom[0] = [examine -decimal sim:/tb_dct_top/dut/u_dct_row/gen_d1/u_rom/rom(0)]"
echo "rom[1] = [examine -decimal sim:/tb_dct_top/dut/u_dct_row/gen_d1/u_rom/rom(1)]"
echo "rom[8] = [examine -decimal sim:/tb_dct_top/dut/u_dct_row/gen_d1/u_rom/rom(8)]"

# Check after a few clocks
run 100ns
echo "=== After 100ns ==="
echo "row engine state = [examine sim:/tb_dct_top/dut/u_dct_row/gen_d1/state]"
echo "row engine ready = [examine sim:/tb_dct_top/dut/u_dct_row/ready]"
echo "row engine y_out = [examine -decimal sim:/tb_dct_top/dut/u_dct_row/y_out]"
echo "row x_reg[0] = [examine -decimal sim:/tb_dct_top/dut/u_dct_row/gen_d1/x_reg(0)]"

# Run until row pass starts
run 5us
echo "=== After 5us ==="
echo "top_state = [examine sim:/tb_dct_top/dut/top_state]"
echo "row engine state = [examine sim:/tb_dct_top/dut/u_dct_row/gen_d1/state]"
echo "row x_reg[0] = [examine -decimal sim:/tb_dct_top/dut/u_dct_row/gen_d1/x_reg(0)]"
echo "mac_accum = [examine -decimal sim:/tb_dct_top/dut/u_dct_row/gen_d1/mac_accum]"
echo "y_out_r = [examine -decimal sim:/tb_dct_top/dut/u_dct_row/gen_d1/y_out_r]"

quit -f
