# wave_quantizer.tcl - ModelSim wave config for tb_quantizer
onerror {resume}
quietly WaveActivateNextPane {} 0

# --- Clock & Control ---
add wave -divider "Clock & Control"
add wave -noupdate -label "clk"        /tb_quantizer/clk
add wave -noupdate -label "rst_n"      /tb_quantizer/rst_n
add wave -noupdate -label "ready"      /tb_quantizer/ready
add wave -noupdate -label "done"       /tb_quantizer/done

# --- Input ---
add wave -divider "Coefficient In"
add wave -noupdate -label "coeff_valid" /tb_quantizer/coeff_valid
add wave -noupdate -label "coeff_in"    -radix decimal /tb_quantizer/coeff_in

# --- Internal ---
add wave -divider "Quantization"
add wave -noupdate -label "Q-table value" -radix unsigned /tb_quantizer/dut/q_val
add wave -noupdate -label "rounding"      -radix decimal /tb_quantizer/dut/round_val

# --- Output ---
add wave -divider "Quotient Out"
add wave -noupdate -label "quant_valid" /tb_quantizer/quant_valid
add wave -noupdate -label "quant_out"   -radix decimal /tb_quantizer/quant_out

TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 160
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
update
WaveRestoreZoom {0 ns} {500 ns}
