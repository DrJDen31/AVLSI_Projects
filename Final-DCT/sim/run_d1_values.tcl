# run_d1_values.tcl - Print actual D1 output values from column DCT
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

vsim -t 1ps -L work work.tb_dct_top -voptargs="+acc" -GNUM_BLOCKS=1

# Wait for block_ready
run 300us

# At this point the testbench should have read the block or block_ready should be high
# Let's just dump the state
echo "=== D1 Final State ==="
echo "block_ready = [examine sim:/tb_dct_top/dut/block_ready]"
echo "ob full = [examine sim:/tb_dct_top/dut/u_output/full]"
echo "coeff_valid = [examine sim:/tb_dct_top/coeff_valid]"
echo "total_compared = [examine -decimal sim:/tb_dct_top/total_compared]"
echo "mismatches = [examine -decimal sim:/tb_dct_top/mismatches]"

quit -f
