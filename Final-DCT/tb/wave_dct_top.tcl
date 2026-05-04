# wave_dct_top.tcl - ModelSim wave config for tb_dct_top
onerror {resume}
quietly WaveActivateNextPane {} 0

# --- Clock & Control ---
add wave -divider "Clock & Control"
add wave -noupdate -label "clk"        /tb_dct_top/clk
add wave -noupdate -label "rst_n"      /tb_dct_top/rst_n
add wave -noupdate -label "block_ready" /tb_dct_top/block_ready
add wave -noupdate -label "block_done"  /tb_dct_top/block_done

# --- Pixel Input ---
add wave -divider "Pixel Input"
add wave -noupdate -label "pixel_valid" /tb_dct_top/pixel_valid
add wave -noupdate -label "pixel_in"   -radix unsigned /tb_dct_top/pixel_in
add wave -noupdate -label "pixel_ready" /tb_dct_top/pixel_ready

# --- DCT Output ---
add wave -divider "DCT Coefficients Out"
add wave -noupdate -label "coeff_rd"    /tb_dct_top/coeff_rd
add wave -noupdate -label "coeff_valid" /tb_dct_top/coeff_valid
add wave -noupdate -label "coeff_out"  -radix decimal  /tb_dct_top/coeff_out

# --- Verification ---
add wave -divider "Verification"
add wave -noupdate -label "golden_idx" -radix unsigned /tb_dct_top/block_coeff_idx
add wave -noupdate -label "mismatches" -radix unsigned /tb_dct_top/mismatches

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 160
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
update
WaveRestoreZoom {0 ns} {500 ns}
