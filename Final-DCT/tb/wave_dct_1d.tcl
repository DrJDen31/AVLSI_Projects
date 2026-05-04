# wave_dct_1d.tcl - ModelSim wave config for tb_dct_1d
onerror {resume}
quietly WaveActivateNextPane {} 0

# --- Clock & Control ---
add wave -divider "Clock & Control"
add wave -noupdate -label "clk"        /tb_dct_1d/clk
add wave -noupdate -label "rst_n"      /tb_dct_1d/rst_n
add wave -noupdate -label "start"      /tb_dct_1d/start
add wave -noupdate -label "ready"      /tb_dct_1d/ready
add wave -noupdate -label "done"       /tb_dct_1d/done

# --- Input Samples ---
add wave -divider "Input Samples"
add wave -noupdate -label "x_valid"    /tb_dct_1d/x_valid
add wave -noupdate -label "x_in"       -radix decimal /tb_dct_1d/x_in

# --- Internal (ROM & MAC) ---
add wave -divider "Internal Processing"
add wave -noupdate -label "rom_addr"   -radix unsigned /tb_dct_1d/dut/rom_addr
add wave -noupdate -label "mac_accum"  -radix decimal /tb_dct_1d/dut/mac_accum

# --- Output Coefficients ---
add wave -divider "Output Coefficients"
add wave -noupdate -label "y_valid"    /tb_dct_1d/y_valid
add wave -noupdate -label "y_out"      -radix decimal /tb_dct_1d/y_out

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 160
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
update
WaveRestoreZoom {0 ns} {500 ns}
