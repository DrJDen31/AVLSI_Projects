# 4. Hardware Implementation Results

## Synthesis Environment
All 7 architectures were implemented in SystemVerilog and synthesized using the **Intel Quartus Prime** toolchain. 
* **Target Device:** Cyclone V (5CGXFC7C7F23C8)
* **Timing Constraint:** 100 MHz clock target (`create_clock -period 10.0`)
* **Analysis Tools:** TimeQuest Timing Analyzer (Fmax), PowerPlay Power Analyzer (Dynamic Power Estimates)

## Automated Results Extraction
An automated Tcl script (`syn/build_all.tcl`) was written to sequentially compile each architecture and pipe the utilization, timing, and power margins into this summary document.

*(Run `quartus_sh -t build_all.tcl` in the `syn/` directory to populate this table)*

## Automated Synthesis Results
| Architecture | ALMs | Registers | DSP Blocks | Fmax (MHz) | Dynamic Power (mW) |
|---|---|---|---|---|---|
| `fir_direct` | | | | | |
| `fir_pipelined` | | | | | |
| `fir_parallel_L2` | | | | | |
| `fir_parallel_L3` | | | | | |
| `fir_fastfir_L2` | | | | | |
| `fir_fastfir_L3` | | | | | |
| `fir_pipe_fastfir_L3` | | | | | |

## Performance Definitions
* **ALMs (Adaptive Logic Modules):** The primary logic resource utilization on the Intel FPGA, representing the combinational and routing area.
* **Registers:** Flip-flop utilization. Heavily influenced by the delay lines and pipelining stages.
* **DSP Blocks:** Dedicated hardware multipliers. Since an $N=175$ tap filter requires hundreds of multiplications, Quartus maps these to DSP blocks.
* **Fmax (Maximum Clock Frequency):** The highest speed the logic can be clocked before violating setup/hold times.
* **Throughput (Samples/sec):** Equal to $F_{max} \times L$, where $L$ is the parallelism level (1, 2, or 3). Higher Fmax and higher $L$ both linearly increase throughput.
