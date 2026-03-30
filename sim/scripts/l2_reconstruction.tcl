# l2_reconstruction.tcl - Reconstructed signal capture (Interleaved L2)
# Run in ModelSim: do sim/scripts/l2_reconstruction.tcl

delete wave *
add wave -noupdate -divider {Control}
add wave -noupdate /fir_tb_L2/clk
add wave -noupdate /fir_tb_L2/rst_n
add wave -noupdate /fir_tb_L2/valid_in
add wave -noupdate /fir_tb_L2/valid_out

add wave -noupdate -divider {Reconstructed Waveforms}
# These signals are interleaved in the testbench for visualization
add wave -noupdate -format Analog-Step -color {Cyan}   -height 120 -max 32767 -min -32768 /fir_tb_L2/data_in_recon
add wave -noupdate -format Analog-Step -color {Yellow} -height 120 -max 32767 -min -32768 /fir_tb_L2/data_out_recon

view wave
wave zoom full
