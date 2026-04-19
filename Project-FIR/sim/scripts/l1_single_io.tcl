# l1_single_io.tcl - Single input and output capture (Direct/Pipelined)
# Run in ModelSim: do sim/scripts/l1_single_io.tcl

delete wave *
add wave -noupdate -divider {Control Signals}
add wave -noupdate /fir_tb_L1/clk
add wave -noupdate /fir_tb_L1/rst_n
add wave -noupdate /fir_tb_L1/valid_in
add wave -noupdate /fir_tb_L1/valid_out

add wave -noupdate -divider {Analog Data I/O}
add wave -noupdate -format Analog-Step -height 80 -max 32767 -min -32768 -color {Cyan}   /fir_tb_L1/data_in
add wave -noupdate -format Analog-Step -height 80 -max 32767 -min -32768 -color {Yellow} /fir_tb_L1/data_out

view wave
wave zoom full
