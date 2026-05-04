# wave_mac_unit.tcl - ModelSim wave config for tb_mac_unit
onerror {resume}
quietly WaveActivateNextPane {} 0

# --- Clock & Control ---
add wave -divider "Clock & Control"
add wave -noupdate -label "clk"        /tb_mac_unit/clk
add wave -noupdate -label "rst_n"      /tb_mac_unit/rst_n
add wave -noupdate -label "clr"        /tb_mac_unit/clr
add wave -noupdate -label "en"         /tb_mac_unit/en

# --- Operands ---
add wave -divider "Operands"
add wave -noupdate -label "operand_a (data)"  -radix decimal /tb_mac_unit/data_in
add wave -noupdate -label "operand_b (coeff)" -radix decimal /tb_mac_unit/coeff_in

# --- Output ---
add wave -divider "Output"
add wave -noupdate -label "accumulator" -radix decimal /tb_mac_unit/dut/accum_reg
add wave -noupdate -label "result"      -radix decimal /tb_mac_unit/accum_out

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 160
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
update
WaveRestoreZoom {0 ns} {500 ns}
