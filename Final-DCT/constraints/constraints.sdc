# constraints.sdc - Quartus TimeQuest constraints for DCT accelerator
# Target: Cyclone V E (5CEBA4F23C7)

# ===========================================================================
# Clock definition
# ===========================================================================
# 100 MHz system clock (10 ns period)
create_clock -name clk -period 10.000 [get_ports clk]

# Clock uncertainty: accounts for PLL jitter and intra-die variation
set_clock_uncertainty -setup 0.200 [get_clocks clk]
set_clock_uncertainty -hold  0.050 [get_clocks clk]

# ===========================================================================
# Input delay constraints
# ===========================================================================
# Assume external inputs arrive 3 ns after the clock edge (source-synchronous)
set_input_delay -clock clk -max 3.000 [get_ports {pixel_in[*] pixel_valid rst_n coeff_rd}]
set_input_delay -clock clk -min 1.000 [get_ports {pixel_in[*] pixel_valid rst_n coeff_rd}]

# ===========================================================================
# Output delay constraints
# ===========================================================================
# Assume outputs must be stable 3 ns before the next clock edge
set_output_delay -clock clk -max 3.000 [get_ports {coeff_out[*] coeff_valid pixel_ready block_ready block_done}]
set_output_delay -clock clk -min 0.500 [get_ports {coeff_out[*] coeff_valid pixel_ready block_ready block_done}]

# ===========================================================================
# Asynchronous reset
# ===========================================================================
# rst_n is treated as asynchronous — set false path to avoid over-constraining
set_false_path -from [get_ports rst_n] -to [all_registers]

# ===========================================================================
# Multicycle paths (if applicable)
# ===========================================================================
# The DSP multiply-accumulate may need multicycle setup depending on Fmax
# Uncomment if synthesis reports timing violations on MAC critical path:
# set_multicycle_path -setup 2 -from [get_registers {*u_mac*product*}] -to [get_registers {*u_mac*accum_out*}]
# set_multicycle_path -hold  1 -from [get_registers {*u_mac*product*}] -to [get_registers {*u_mac*accum_out*}]
