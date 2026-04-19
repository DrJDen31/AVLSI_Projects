# showcase_all.tcl - Automate all 7 FIR simulations in ModelSim
# Run from project root: vsim -c -do sim/showcase_all.tcl

proc run_arch {name tb_file l_factor} {
    puts "\n>>> SIMULATING: $name (L=$l_factor)"
    vlib work
    vlog -sv rtl/coeff_pkg.sv rtl/${name}.sv tb/${tb_file}
    
    # Start simulation
    vsim -c work.${tb_file%%.sv}
    
    # Add waves if running in GUI (ignored in -c mode)
    add wave -hex /${tb_file%%.sv}/dut/*
    
    # Run
    run -all
    
    # Finalize
    quit -sim
}

# Run all 7
run_arch "fir_direct"          "fir_tb_L1.sv" 1
run_arch "fir_pipelined"       "fir_tb_L1.sv" 1
run_arch "fir_parallel_L2"     "fir_tb_L2.sv" 2
run_arch "fir_parallel_L3"     "fir_tb_L3.sv" 3
run_arch "fir_fastfir_L2"      "fir_tb_L2.sv" 2
run_arch "fir_fastfir_L3"      "fir_tb_L3.sv" 3
run_arch "fir_pipe_fastfir_L3" "fir_tb_L3.sv" 3

puts "\n*** All simulations completed! ***"
exit
