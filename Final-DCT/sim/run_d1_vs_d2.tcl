# run_d1_vs_d2.tcl - Compare D1 and D2 column input data
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

# Run D1
vsim -t 1ps -L work work.tb_dct_top -voptargs="+acc"

# Break when first col_start fires
when -label col0 {sim:/tb_dct_top/dut/col_start == 1} {
    echo "=== D1 col_start: col_cnt=[examine sim:/tb_dct_top/dut/col_pass_cnt] ==="
    for {set i 0} {$i < 8} {incr i} {
        echo "  col_input_buf[$i] = [examine -decimal sim:/tb_dct_top/dut/col_input_buf($i)]"
    }
    nowhen col0
}

# Break when first col_done fires
when -label cdone {sim:/tb_dct_top/dut/col_done == 1} {
    echo "=== D1 col_done: col_cnt=[examine sim:/tb_dct_top/dut/col_pass_cnt] ==="
    echo "  col_y_out = [examine -decimal sim:/tb_dct_top/dut/col_y_out]"
    echo "  ob_coeff_in = [examine -decimal sim:/tb_dct_top/dut/ob_coeff_in]"
    nowhen cdone
}

run 30us
quit -f
