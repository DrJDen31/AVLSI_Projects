# run_sim_d2_debug3.tcl - Run D2 longer with increased timeout
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

# Modified testbench inline: just test 1 block with longer timeout
vlog -sv +define+SIM_TIMEOUT=100000000 ../tb/tb_dct_top.sv

file copy -force ../matlab/outputs/test_vectors.hex .
file copy -force ../matlab/outputs/golden_coeffs_fixed.txt .

vsim -t 1ps -L work work.tb_dct_top -voptargs="+acc" -GPIPELINE_STAGES=4

run 25us

echo "=== State at 25us ==="
echo "top_state = [examine sim:/tb_dct_top/dut/top_state]"
echo "col_pass_cnt = [examine sim:/tb_dct_top/dut/col_pass_cnt]"
echo "ob wr_ptr = [examine sim:/tb_dct_top/dut/u_output/wr_ptr]"
echo "ob full = [examine sim:/tb_dct_top/dut/u_output/full]"
echo "block_ready = [examine sim:/tb_dct_top/dut/block_ready]"

quit -f
