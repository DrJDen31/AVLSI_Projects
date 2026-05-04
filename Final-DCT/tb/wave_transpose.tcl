# wave_transpose.tcl - ModelSim wave config for tb_transpose
onerror {resume}
quietly WaveActivateNextPane {} 0

# --- Clock & Control ---
add wave -divider "Clock & Control"
add wave -noupdate -label "clk"        /tb_transpose/clk
add wave -noupdate -label "rst_n"      /tb_transpose/rst_n

# --- Write Interface (Row-Major) ---
add wave -divider "Write Interface (Row-Major)"
add wave -noupdate -label "wr_valid"   /tb_transpose/wr_valid
add wave -noupdate -label "wr_data"    -radix decimal /tb_transpose/wr_data
add wave -noupdate -label "wr_row"     -radix unsigned /tb_transpose/dut/wr_row
add wave -noupdate -label "wr_col"     -radix unsigned /tb_transpose/dut/wr_col

# --- Read Interface (Column-Major) ---
add wave -divider "Read Interface (Column-Major)"
add wave -noupdate -label "rd_valid"   /tb_transpose/rd_valid
add wave -noupdate -label "rd_data"    -radix decimal /tb_transpose/rd_data
add wave -noupdate -label "rd_col"     -radix unsigned /tb_transpose/dut/rd_col
add wave -noupdate -label "rd_row"     -radix unsigned /tb_transpose/dut/rd_row

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 180
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
update
WaveRestoreZoom {0 ns} {800 ns}
