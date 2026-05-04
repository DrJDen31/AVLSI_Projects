# run_d1_xreg_debug.tcl - Check x_reg during load
quit -sim

if {[file exists work]} { vdel -lib work -all }
vlib work
vmap work work

vlog -sv ../rtl/mac_unit.sv
vlog -sv ../rtl/coefficient_rom.sv
vlog -sv ../rtl/dct_1d_engine.sv
vlog -sv ../tb/tb_dct_1d.sv

vsim -t 1ps -L work work.tb_dct_1d -voptargs="+acc"

# Monitor x_reg writes during S_LOAD
when -label xreg_watch {sim:/tb_dct_1d/dut/state == S_LOAD and sim:/tb_dct_1d/x_valid == 1} {
    echo "[now] LOAD: load_cnt=[examine -decimal sim:/tb_dct_1d/dut/load_cnt] x_in=[examine -decimal sim:/tb_dct_1d/dut/x_in] x_valid=[examine sim:/tb_dct_1d/dut/x_valid]"
}

run 250ns

echo "=== All x_reg values ==="
for {set i 0} {$i < 8} {incr i} {
    echo "  x_reg[$i] = [examine -decimal sim:/tb_dct_1d/dut/x_reg($i)]"
}
echo "mac_accum = [examine -decimal sim:/tb_dct_1d/dut/mac_accum]"

quit -f
