# run_d1_trace.tcl - Trace D1 output values
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

# Trace every OB write
set ::ob_count 0
when -label watch_ob {sim:/tb_dct_top/dut/u_output/coeff_valid == 1 and sim:/tb_dct_top/dut/u_output/full == 0} {
    if {$::ob_count < 16} {
        echo "D1 OB write [$::ob_count] wr_ptr=[examine sim:/tb_dct_top/dut/u_output/wr_ptr] val=[examine -decimal sim:/tb_dct_top/dut/u_output/coeff_in]"
    }
    incr ::ob_count
}

run 300us
echo "Total OB writes: $::ob_count"
quit -f
