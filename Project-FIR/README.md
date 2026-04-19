# Advanced VLSI FIR Filter Architecture Space Exploration

A comprehensive course project implementing a 175-tap low-pass FIR filter across 7 distinct algorithmic architectures in SystemVerilog, targeting an Intel Cyclone V FPGA.

## **[Final Project Report](report/report.pdf)**
[(LaTeX Source)](report/report.tex)
> **Key Results:** Achieved **205.2 MSPS** throughput with **0.67 mW/MSPS** power efficiency using a Pipelined Fast FIR ($L=3$) architecture. This project demonstrates massive throughput scaling through polyphase decomposition and algorithmic reduction (FFA).

---

## Project Documentation
The complete hardware evaluation and design process, including architectural diagrams and comparative analysis, is available in the final report linked above. For detailed breakdowns of specific design phases, see the following:

1. [**MATLAB Filter Design**](docs/1_matlab_design.md): Details the 175-tap Parks-McClellan (`firpm`) filter design and automated test vector generation.
2. [**Quantization Analysis & Overflow Prevention**](docs/2_quantization.md): Proves the necessity of 22 fractional bits to achieve the 80 dB attenuation spec and derives the 49-bit mathematically safe accumulator width.
3. [**Architectural Designs**](docs/3_architecture.md): Explains the block-level structure of all 7 SystemVerilog pipelines (Direct, Pipelined, Simple Parallel, and Fast FIR).
4. [**Hardware Implementation Results**](docs/4_hw_results.md): The raw ALM, DSP, Fmax, and Power numbers extracted directly from Intel Quartus.
5. [**Performance Trade-off Analysis**](docs/5_analysis.md): A detailed conclusion comparing the multiplicative savings of Fast FIR vs. Simple Parallelism, and the $F_{max}$ impact of pipeline isolation.

## Implemented Architectures

The `rtl/` directory contains 7 parameterized top-level modules sharing a common AXI-Stream-style valid handshake interface. They all import the auto-generated `coeff_pkg.sv` constants package.

| Module | Features | Multipliers Required | Latency (cycles) | Throughput |
|---|---|---|---|---|
| `fir_direct.sv` | Baseline combinational MACC tree | $N=175$ | 1 | 1 sample/cycle |
| `fir_pipelined.sv` | M=4 granularity pipelined adder arrays | $N=175$ | 45 | 1 sample/cycle |
| `fir_parallel_L2.sv` | Simple polyphase decomposition $L=2$ | $2N=350$ | 1 | 2 samples/cycle |
| `fir_parallel_L3.sv` | Simple polyphase decomposition $L=3$ | $3N=525$ | 1 | 3 samples/cycle |
| `fir_fastfir_L2.sv` | **Fast FIR Algorithm $L=2$** (Reduced Complexity) | $1.5N=263$ | 1 | 2 samples/cycle |
| `fir_fastfir_L3.sv` | **Fast FIR Algorithm $L=3$** (Reduced Complexity) | $2N=350$ | 1 | 3 samples/cycle |
| `fir_pipe_fastfir_L3.sv` | **Pipelined Fast FIR $L=3$** | $2N=350$ | 16 | 3 samples/cycle |

## How to Reproduce

### 1. Generating Coefficients and Test Vectors
The `/matlab` directory contains the scripts to calculate the 175-tap equiripple filter, determine bit constraints, and generate the hex inputs/outputs.
```bash
# In MATLAB, navigate to /matlab
>> fir_design
>> quantize_coeffs
>> gen_test_vectors
```

### 2. RTL Simulation
A universal testbench `tb/fir_tb.sv` automatically tests any of the architectures strictly against the golden integer-convolution MATLAB outputs.
* Load `fir_tb.sv` and `rtl/coeff_pkg.sv` + the target architecture into ModelSim.
* Ensure the working directory contains `tb/test_vectors/input_stimulus.hex` and `golden_output.hex`.

### 3. Automated FPGA Synthesis
An automation script (`syn/build_all.tcl`) compiles all 7 architectures sequentially in Quartus and produces the summary comparison table.
```bash
cd syn
quartus_sh -t build_all.tcl
```
*(Results are appended directly to `docs/4_hw_results.md`)*
