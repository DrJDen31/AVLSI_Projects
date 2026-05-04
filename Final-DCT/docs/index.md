# 2D DCT Accelerator

Welcome to the 2D DCT Image Compression Accelerator documentation site.

This project implements a multi-variant 2D Discrete Cosine Transform hardware accelerator in SystemVerilog, targeting 100 MHz performance for JPEG image compression.

## Performance Overview

![Performance Comparison](figures/perf_comparison.png)

| Design Variant | Throughput | Area (ALMs) | Fmax (MHz) |
|----------------|------------|-------------|------------|
| D1: Baseline   | 1/8 pix/cyc| 320         | 105        |
| D2: Pipelined  | 1/8 pix/cyc| 450         | 210        |
| D3: Parallel   | 1 pix/cyc  | 2100        | 85         |
| D4: Pipe+Para  | 1 pix/cyc  | 2600        | 195        |

Explore the site for full architectural details, simulation results, and the image gallery.
