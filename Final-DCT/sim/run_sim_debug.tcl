# run_sim_debug.tcl - Debug simulation: just run block 0 with verbose waveforms
quit -sim

if {[file exists work]} {
    vdel -lib work -all
}
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

# Add key signals
add wave -divider "Testbench"
add wave sim:/tb_dct_top/clk
add wave sim:/tb_dct_top/rst_n
add wave sim:/tb_dct_top/pixel_in
add wave sim:/tb_dct_top/pixel_valid
add wave sim:/tb_dct_top/pixel_ready
add wave sim:/tb_dct_top/coeff_out
add wave sim:/tb_dct_top/coeff_valid
add wave sim:/tb_dct_top/coeff_rd
add wave sim:/tb_dct_top/block_ready
add wave sim:/tb_dct_top/block_done

add wave -divider "Top FSM"
add wave sim:/tb_dct_top/dut/top_state
add wave sim:/tb_dct_top/dut/row_pass_cnt
add wave sim:/tb_dct_top/dut/row_feed_cnt
add wave sim:/tb_dct_top/dut/row_pass_feeding
add wave sim:/tb_dct_top/dut/row_pass_started
add wave sim:/tb_dct_top/dut/col_pass_cnt
add wave sim:/tb_dct_top/dut/col_feed_cnt
add wave sim:/tb_dct_top/dut/col_pass_feeding
add wave sim:/tb_dct_top/dut/col_pass_started
add wave sim:/tb_dct_top/dut/col_buf_ready
add wave sim:/tb_dct_top/dut/col_buf_wr_ptr

add wave -divider "PBB"
add wave sim:/tb_dct_top/dut/pbb_block_loaded
add wave sim:/tb_dct_top/dut/pbb_block_done
add wave sim:/tb_dct_top/dut/pbb_sample
add wave sim:/tb_dct_top/dut/pbb_sample_valid
add wave sim:/tb_dct_top/dut/pbb_sample_req
add wave sim:/tb_dct_top/dut/u_pbb/wr_ptr
add wave sim:/tb_dct_top/dut/u_pbb/rd_ptr
add wave sim:/tb_dct_top/dut/u_pbb/reading

add wave -divider "Row DCT"
add wave sim:/tb_dct_top/dut/row_start
add wave sim:/tb_dct_top/dut/row_x_in
add wave sim:/tb_dct_top/dut/row_x_valid
add wave sim:/tb_dct_top/dut/row_y_out
add wave sim:/tb_dct_top/dut/row_y_valid
add wave sim:/tb_dct_top/dut/row_done
add wave sim:/tb_dct_top/dut/row_ready
add wave sim:/tb_dct_top/dut/u_dct_row/gen_d1/state
add wave sim:/tb_dct_top/dut/u_dct_row/gen_d1/load_cnt
add wave sim:/tb_dct_top/dut/u_dct_row/gen_d1/k_idx
add wave sim:/tb_dct_top/dut/u_dct_row/gen_d1/phase

add wave -divider "Transpose"
add wave sim:/tb_dct_top/dut/tb_wr_data
add wave sim:/tb_dct_top/dut/tb_wr_valid
add wave sim:/tb_dct_top/dut/tb_wr_done
add wave sim:/tb_dct_top/dut/tb_rd_data
add wave sim:/tb_dct_top/dut/tb_rd_en
add wave sim:/tb_dct_top/dut/tb_rd_valid
add wave sim:/tb_dct_top/dut/tb_rd_done
add wave sim:/tb_dct_top/dut/tb_ready
add wave sim:/tb_dct_top/dut/u_transpose/state
add wave sim:/tb_dct_top/dut/u_transpose/wr_cnt
add wave sim:/tb_dct_top/dut/u_transpose/rd_cnt

add wave -divider "Col DCT"
add wave sim:/tb_dct_top/dut/col_start
add wave sim:/tb_dct_top/dut/col_x_in
add wave sim:/tb_dct_top/dut/col_x_valid
add wave sim:/tb_dct_top/dut/col_y_out
add wave sim:/tb_dct_top/dut/col_y_valid
add wave sim:/tb_dct_top/dut/col_done
add wave sim:/tb_dct_top/dut/col_ready

add wave -divider "Output"
add wave sim:/tb_dct_top/dut/ob_coeff_in
add wave sim:/tb_dct_top/dut/ob_coeff_valid
add wave sim:/tb_dct_top/dut/u_output/wr_ptr
add wave sim:/tb_dct_top/dut/u_output/full
add wave sim:/tb_dct_top/dut/u_output/rd_ptr
add wave sim:/tb_dct_top/dut/u_output/reading

# Run for a short time to see where it stalls
run 100us

# Check state
echo "=== Final state ==="
echo "top_state = [examine sim:/tb_dct_top/dut/top_state]"
echo "row_pass_cnt = [examine sim:/tb_dct_top/dut/row_pass_cnt]"
echo "row_pass_started = [examine sim:/tb_dct_top/dut/row_pass_started]"
echo "row_pass_feeding = [examine sim:/tb_dct_top/dut/row_pass_feeding]"
echo "pbb_block_loaded = [examine sim:/tb_dct_top/dut/pbb_block_loaded]"
echo "pbb_sample_req = [examine sim:/tb_dct_top/dut/pbb_sample_req]"
echo "pbb_sample_valid = [examine sim:/tb_dct_top/dut/pbb_sample_valid]"
echo "row_ready = [examine sim:/tb_dct_top/dut/row_ready]"
echo "row DCT state = [examine sim:/tb_dct_top/dut/u_dct_row/gen_d1/state]"
echo "pbb rd_ptr = [examine sim:/tb_dct_top/dut/u_pbb/rd_ptr]"
echo "pbb reading = [examine sim:/tb_dct_top/dut/u_pbb/reading]"
echo "transpose state = [examine sim:/tb_dct_top/dut/u_transpose/state]"
echo "transpose wr_cnt = [examine sim:/tb_dct_top/dut/u_transpose/wr_cnt]"
echo "col_pass_cnt = [examine sim:/tb_dct_top/dut/col_pass_cnt]"
echo "col_buf_ready = [examine sim:/tb_dct_top/dut/col_buf_ready]"
echo "col_pass_started = [examine sim:/tb_dct_top/dut/col_pass_started]"
echo "col_done = [examine sim:/tb_dct_top/dut/col_done]"
echo "col_ready = [examine sim:/tb_dct_top/dut/col_ready]"
echo "ob wr_ptr = [examine sim:/tb_dct_top/dut/u_output/wr_ptr]"
echo "ob full = [examine sim:/tb_dct_top/dut/u_output/full]"
echo "block_ready = [examine sim:/tb_dct_top/dut/block_ready]"
echo "block_done = [examine sim:/tb_dct_top/dut/block_done]"

quit -f
