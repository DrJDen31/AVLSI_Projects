# run_sim_d1_obdump.tcl - Dump D1 output buffer to compare ordering with D2
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

# D1 default parameters
vsim -t 1ps -L work work.tb_dct_top -voptargs="+acc"

# Wait for block 0 to complete
when -label block0done {sim:/tb_dct_top/dut/block_ready == 1} {
    echo "BLOCK_READY at [now]"
    echo "ob wr_ptr = [examine sim:/tb_dct_top/dut/u_output/wr_ptr]"
    for {set i 0} {$i < 16} {incr i} {
        echo "D1 ob mem[$i] = [examine -decimal sim:/tb_dct_top/dut/u_output/mem($i)]"
    }
    stop
}

run 300us
quit -f
