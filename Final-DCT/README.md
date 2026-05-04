# 2D DCT Image Compression Accelerator

**Course:** Advanced VLSI Design  
**Description:** A highly parameterized, multi-variant 2D Discrete Cosine Transform (DCT) hardware accelerator in SystemVerilog, optimized for JPEG image compression.

## Project Resources

- **[Final Technical Report (PDF)](report/main.pdf)**: Comprehensive documentation detailing the architecture, synthesis results, and verification methodology.
- **[Top-Level RTL](rtl/top_dct_accelerator.sv)**: The primary SystemVerilog module integrating the row engine, transpose buffer, column engine, and quantizer.
- **[System Testbench](tb/tb_dct_top.sv)**: The automated verification testbench that checks the RTL outputs against the mathematical model.
- **[Python Analysis Suite](python/)**: A suite of scripts to generate the floating-point golden reference data, reconstruct the image, and statistically plot the reconstruction fidelity.

## Architecture

![Architecture Block Diagram](report/figures/rtl_viewer_D4.png)
*(High level D4 RTL Viewer Schematic. See the [Final Technical Report](report/main.pdf) for full microarchitectural details)*

## Results Summary

| Design | Throughput (Pixels/Cycle) | Fmax (MHz) | ALMs (Area) | PSNR (dB) |
|--------|---------------------------|------------|-------------|-----------|
| D1 (Baseline) | 1/8 | 148 | 320 | 51.05 |
| D2 (Pipelined) | 1/8 | 192 | 345 | 51.05 |
| D3 (Parallel) | 1 | 140 | 2,150 | 51.05 |
| D4 (Pipe+Parallel)| 1 | 195 | 2,600 | 51.05 |

*See Section 4 of the [Final Technical Report](report/main.pdf) for the full metrics, Pareto-efficiency analysis, and synthesis data.*

## Visual Results

![Original vs Reconstructed](report/figures/image_comparison.png)
