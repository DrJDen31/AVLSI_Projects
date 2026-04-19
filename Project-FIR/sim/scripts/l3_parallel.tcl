# l3_parallel.tcl - 3 In / 3 Out parallel capture (L3 architectures)
# Run in ModelSim: do sim/scripts/l3_parallel.tcl

delete wave *
add wave -noupdate -divider {Control}
add wave -noupdate /fir_tb_L3/clk
add wave -noupdate /fir_tb_L3/rst_n
add wave -noupdate /fir_tb_L3/valid_in
add wave -noupdate /fir_tb_L3/valid_out

add wave -noupdate -divider {Parallel Inputs}
add wave -noupdate -format Analog-Step -height 45 -max 32767 -min -32768 -color {Cyan}        /fir_tb_L3/data_in0
add wave -noupdate -format Analog-Step -height 45 -max 32767 -min -32768 -color {Blue}        /fir_tb_L3/data_in1
add wave -noupdate -format Analog-Step -height 45 -max 32767 -min -32768 -color {Aquamarine}  /fir_tb_L3/data_in2

add wave -noupdate -divider {Parallel Outputs}
add wave -noupdate -format Analog-Step -height 45 -max 32767 -min -32768 -color {Yellow}      /fir_tb_L3/data_out0
add wave -noupdate -format Analog-Step -height 45 -max 32767 -min -32768 -color {Orange}      /fir_tb_L3/data_out1
add wave -noupdate -format Analog-Step -height 45 -max 32767 -min -32768 -color {Gold}        /fir_tb_L3/data_out2

view wave
wave zoom full
