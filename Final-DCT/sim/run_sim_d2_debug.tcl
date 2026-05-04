# run_sim_d2_debug.tcl - Debug D2 system-level to find mismatch source
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

vsim -t 1ps -L work work.tb_dct_top -voptargs="+acc" -GPIPELINE_STAGES=4

# Monitor output coefficients
when -label watch_coeff {sim:/tb_dct_top/dut/ob_coeff_valid == 1} {
    echo "[now] OB_COEFF wr_ptr=[examine sim:/tb_dct_top/dut/u_output/wr_ptr] val=[examine -decimal sim:/tb_dct_top/dut/ob_coeff_in]"
}

# Monitor col DCT outputs
when -label watch_col_y {sim:/tb_dct_top/dut/col_y_valid == 1} {
    echo "[now] COL_Y col_cnt=[examine sim:/tb_dct_top/dut/col_pass_cnt] val=[examine -decimal sim:/tb_dct_top/dut/col_y_out]"
}

# Monitor row DCT outputs
when -label watch_row_y {sim:/tb_dct_top/dut/row_y_valid == 1} {
    echo "[now] ROW_Y row_cnt=[examine sim:/tb_dct_top/dut/row_pass_cnt] val=[examine -decimal sim:/tb_dct_top/dut/row_y_out]"
}

run 20us

quit -f
