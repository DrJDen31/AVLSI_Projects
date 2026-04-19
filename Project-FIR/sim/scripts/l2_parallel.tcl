# l2_parallel.tcl - 2 In / 2 Out parallel capture (L2 architectures)
# Run in ModelSim: do sim/scripts/l2_parallel.tcl

delete wave *
add wave -noupdate -divider {Control}
add wave -noupdate /fir_tb_L2/clk
add wave -noupdate /fir_tb_L2/rst_n
add wave -noupdate /fir_tb_L2/valid_in
add wave -noupdate /fir_tb_L2/valid_out

add wave -noupdate -divider {Parallel Inputs}
add wave -noupdate -format Analog-Step -height 50 -max 32767 -min -32768 -color {Cyan}        /fir_tb_L2/data_in0
add wave -noupdate -format Analog-Step -height 50 -max 32767 -min -32768 -color {Blue}        /fir_tb_L2/data_in1

add wave -noupdate -divider {Parallel Outputs}
add wave -noupdate -format Analog-Step -height 50 -max 32767 -min -32768 -color {Yellow}      /fir_tb_L2/data_out0
add wave -noupdate -format Analog-Step -height 50 -max 32767 -min -32768 -color {Orange}      /fir_tb_L2/data_out1

view wave
wave zoom full
