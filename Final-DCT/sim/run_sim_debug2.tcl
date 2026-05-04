# run_sim_debug2.tcl - Short debug run to find exact stall point
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

# Monitor state transitions
when -label watch_state {sim:/tb_dct_top/dut/top_state'event} {
    echo "[now] top_state = [examine sim:/tb_dct_top/dut/top_state]  row_cnt=[examine sim:/tb_dct_top/dut/row_pass_cnt]  col_cnt=[examine sim:/tb_dct_top/dut/col_pass_cnt]"
}

when -label watch_row_done {sim:/tb_dct_top/dut/row_done == 1} {
    echo "[now] ROW_DONE row_cnt=[examine sim:/tb_dct_top/dut/row_pass_cnt]  tb_wr_cnt=[examine sim:/tb_dct_top/dut/u_transpose/wr_cnt]  pbb_rd=[examine sim:/tb_dct_top/dut/u_pbb/rd_ptr]"
}

when -label watch_pbb_done {sim:/tb_dct_top/dut/pbb_block_done == 1} {
    echo "[now] PBB_BLOCK_DONE rd_ptr=[examine sim:/tb_dct_top/dut/u_pbb/rd_ptr] reading=[examine sim:/tb_dct_top/dut/u_pbb/reading] row_cnt=[examine sim:/tb_dct_top/dut/row_pass_cnt]"
}

when -label watch_row_start {sim:/tb_dct_top/dut/row_start == 1} {
    echo "[now] ROW_START row_cnt=[examine sim:/tb_dct_top/dut/row_pass_cnt] dct_state=[examine sim:/tb_dct_top/dut/u_dct_row/gen_d1/state]"
}

run 20us

echo "=== State at 20us ==="
echo "top_state = [examine sim:/tb_dct_top/dut/top_state]"
echo "row_pass_cnt = [examine sim:/tb_dct_top/dut/row_pass_cnt]"
echo "row_pass_started = [examine sim:/tb_dct_top/dut/row_pass_started]"
echo "row_pass_feeding = [examine sim:/tb_dct_top/dut/row_pass_feeding]"
echo "row_feed_cnt = [examine sim:/tb_dct_top/dut/row_feed_cnt]"
echo "pbb_block_loaded = [examine sim:/tb_dct_top/dut/pbb_block_loaded]"
echo "pbb_sample_valid = [examine sim:/tb_dct_top/dut/pbb_sample_valid]"
echo "pbb_sample_req = [examine sim:/tb_dct_top/dut/pbb_sample_req]"
echo "pbb reading = [examine sim:/tb_dct_top/dut/u_pbb/reading]"
echo "pbb rd_ptr = [examine sim:/tb_dct_top/dut/u_pbb/rd_ptr]"
echo "row_ready = [examine sim:/tb_dct_top/dut/row_ready]"
echo "row DCT state = [examine sim:/tb_dct_top/dut/u_dct_row/gen_d1/state]"
echo "row DCT load_cnt = [examine sim:/tb_dct_top/dut/u_dct_row/gen_d1/load_cnt]"

quit -f
