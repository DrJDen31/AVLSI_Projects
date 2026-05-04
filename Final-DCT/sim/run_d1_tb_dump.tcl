# run_d1_tb_dump.tcl - Dump transpose buffer after row pass for D1
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

# Wait for TOP_TRANSPOSE state
when -label tbdump {sim:/tb_dct_top/dut/top_state == TOP_TRANSPOSE} {
    echo "=== Transpose buffer contents (D1 row=0..7, col=0..7) ==="
    for {set r 0} {$r < 8} {incr r} {
        set row_vals ""
        for {set c 0} {$c < 8} {incr c} {
            append row_vals "[examine -decimal sim:/tb_dct_top/dut/u_transpose/mem($r)($c)] "
        }
        echo "  row $r: $row_vals"
    }
    nowhen tbdump
}

run 20us

quit -f
