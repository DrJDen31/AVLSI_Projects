# 2D DCT Accelerator Results

This document contains the performance metrics and verification results for all four design variants of the 2D DCT Accelerator.

## Performance Metrics Summary

| Design Point | Latency (Cycles) | Throughput (Pixels/Cycle) | PSNR (dB) | Fmax (MHz) |
|--------------|------------------|---------------------------|-----------|------------|
| **D1: Baseline** | 512 | 1/8 | 51.05 | 105 |
| **D2: Pipelined** | 512 | 1/8 | 51.05 | 210 |
| **D3: Parallel** | 64 | 1 | 51.05 | 85 |
| **D4: Pipelined + Parallel** | 64 | 1 | 51.05 | 195 |

## Synthesis Results

*(Quartus RTL screenshot thumbnails will be added here, linked to full-size images in `synth/`)*

## Timing and Constraints

- Target Frequency: 100 MHz
- *(Notes on any designs that didn't meet the 100 MHz SDC constraint will be documented here)*
