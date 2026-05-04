@echo off
echo Running D1
vsim -c -do "vsim -t 1ps -L work work.tb_dct_top -GPARALLEL=0 -GPIPELINE_STAGES=1 +FILENAME=sim_coeffs_D1.txt; run -all; quit -f"
echo Running D2
vsim -c -do "vsim -t 1ps -L work work.tb_dct_top -GPARALLEL=0 -GPIPELINE_STAGES=4 +FILENAME=sim_coeffs_D2.txt; run -all; quit -f"
echo Running D3
vsim -c -do "vsim -t 1ps -L work work.tb_dct_top -GPARALLEL=1 -GPIPELINE_STAGES=1 +FILENAME=sim_coeffs_D3.txt; run -all; quit -f"
echo Running D4
vsim -c -do "vsim -t 1ps -L work work.tb_dct_top -GPARALLEL=1 -GPIPELINE_STAGES=4 +FILENAME=sim_coeffs_D4.txt; run -all; quit -f"
python compare_golden.py
