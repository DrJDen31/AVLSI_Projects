# run_sim_d2_debug2.tcl - Count exact OB writes for D2
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

# Wait until block_ready fires for block 0
run 15us

echo "=== After block 0 ==="
echo "block_ready = [examine sim:/tb_dct_top/dut/block_ready]"
echo "ob wr_ptr = [examine sim:/tb_dct_top/dut/u_output/wr_ptr]"
echo "ob full = [examine sim:/tb_dct_top/dut/u_output/full]"

# Dump first 16 output buffer entries
for {set i 0} {$i < 64} {incr i} {
    echo "ob mem[$i] = [examine -decimal sim:/tb_dct_top/dut/u_output/mem($i)]"
}

quit -f
