# l2_latency.tcl - Latency capture highlighting input-to-output shift
# Run in ModelSim: do sim/scripts/l2_latency.tcl

delete wave *
add wave -noupdate -divider {Timing Basics}
add wave -noupdate /fir_tb_L2/clk
add wave -noupdate /fir_tb_L2/valid_in
add wave -noupdate /fir_tb_L2/valid_out

add wave -noupdate -divider {Latency Analysis}
add wave -noupdate -format Analog-Step -height 80 -max 32767 -min -32768 -color {Cyan}   /fir_tb_L2/data_in0
add wave -noupdate -format Analog-Step -height 80 -max 32767 -min -32768 -color {Yellow} /fir_tb_L2/data_out0

view wave
# Zoom into the first few samples to see the latency shift
wave zoom range {120 ns} {150 ns}
