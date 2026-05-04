# run_sim_debug3.tcl - Debug column pass
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

when -label watch_col {sim:/tb_dct_top/dut/col_done == 1} {
    echo "[now] COL_DONE col_cnt=[examine sim:/tb_dct_top/dut/col_pass_cnt] ob_wr=[examine sim:/tb_dct_top/dut/u_output/wr_ptr]"
}

when -label watch_tb_rd {sim:/tb_dct_top/dut/tb_rd_valid == 1} {
    echo "[now] TB_RD_VALID col_buf_wr=[examine sim:/tb_dct_top/dut/col_buf_wr_ptr] col_buf_rdy=[examine sim:/tb_dct_top/dut/col_buf_ready]"
}

when -label watch_col_start {sim:/tb_dct_top/dut/col_start == 1} {
    echo "[now] COL_START col_cnt=[examine sim:/tb_dct_top/dut/col_pass_cnt] col_state=[examine sim:/tb_dct_top/dut/u_dct_col/gen_d1/state]"
}

run 50us

echo "=== State at 50us ==="
echo "top_state = [examine sim:/tb_dct_top/dut/top_state]"
echo "col_pass_cnt = [examine sim:/tb_dct_top/dut/col_pass_cnt]"
echo "col_pass_started = [examine sim:/tb_dct_top/dut/col_pass_started]"
echo "col_pass_feeding = [examine sim:/tb_dct_top/dut/col_pass_feeding]"
echo "col_waiting_done = [examine sim:/tb_dct_top/dut/col_waiting_done]"
echo "col_feed_cnt = [examine sim:/tb_dct_top/dut/col_feed_cnt]"
echo "col_buf_ready = [examine sim:/tb_dct_top/dut/col_buf_ready]"
echo "col_buf_wr_ptr = [examine sim:/tb_dct_top/dut/col_buf_wr_ptr]"
echo "tb_rd_en = [examine sim:/tb_dct_top/dut/tb_rd_en]"
echo "tb_rd_valid = [examine sim:/tb_dct_top/dut/tb_rd_valid]"
echo "tb state = [examine sim:/tb_dct_top/dut/u_transpose/state]"
echo "tb rd_cnt = [examine sim:/tb_dct_top/dut/u_transpose/rd_cnt]"
echo "col DCT state = [examine sim:/tb_dct_top/dut/u_dct_col/gen_d1/state]"
echo "col DCT load_cnt = [examine sim:/tb_dct_top/dut/u_dct_col/gen_d1/load_cnt]"
echo "ob wr_ptr = [examine sim:/tb_dct_top/dut/u_output/wr_ptr]"
echo "block_ready = [examine sim:/tb_dct_top/dut/block_ready]"

quit -f
