# Comprehensive Image Gallery

This gallery serves as a centralized collection of all visualizations, charts, and hardware screenshots generated for the 2D DCT Accelerator project.

## 1. Visual Reconstruction

### Reconstructed Image Output
![Original vs Reconstructed](figures/image_comparison.png)
*Side-by-side comparison of the original image and the RTL reconstructed output for D1 and D4, alongside heatmaps of the absolute error.*

## 2. Error and Fidelity Analysis

### Error Histogram
![Error Histogram](figures/error_histogram.png)
*Distribution of pixel-wise errors between the original image and the D4 reconstructed output.*

### 2D DCT Energy Concentration
![Energy Heatmap](figures/energy_heatmap.png)
*Heatmap showing the concentration of signal energy in the low-frequency DCT coefficients.*

### PSNR vs Quantization Factor
![PSNR vs QF](figures/psnr_vs_qf.png)
*Relationship between the JPEG Quantization Quality Factor and the resulting Peak Signal-to-Noise Ratio (PSNR).*

## 3. Hardware & Performance Metrics

### Throughput Comparison
![Performance Comparison](figures/perf_comparison.png)
*Bar chart comparing the raw throughput (in Million Blocks / sec) across the four design variants.*

### Hardware Resource Breakdown
![Hardware Resource Breakdown](figures/hardware_breakdown.png)
*Detailed resource breakdown across the four design variants, highlighting ALMs, Registers, and DSP block usage.*

### Area-Throughput Trade-off
![Area vs Throughput](figures/area_throughput.png)
*Scatter plot illustrating the Pareto frontier of area vs. throughput for the implemented architectures.*

### Area Efficiency
![Efficiency](figures/efficiency.png)
*Throughput-per-Area efficiency (Blocks/sec per ALM) showing the relative utilization effectiveness of each design.*

## 4. Architecture & Timing

### Pipeline Waveform
![Pipeline Waveform](figures/pipeline_waveform.png)
*Waveform diagram illustrating the pipeline stages and data flow through the architecture.*

### System Block Diagram
![System Block Diagram](figures/system_block_diagram.png)
*Top-level module hierarchy and system block diagram.*

### MAC Unit Schematic
![MAC Unit Schematic](figures/mac_unit_schematic.png)
*Logic schematic for the Multiply-Accumulate (MAC) unit used in the parallel 1D engine.*


## 5. RTL Synthesis Artifacts

*The following images are placeholders for screenshots to be manually captured from the Intel Quartus GUI and placed into the `docs/figures/` directory.*

### D1: Baseline RTL Schematic
![D1 RTL Viewer](figures/rtl_viewer_D1.png)

### D2: Pipelined RTL Schematic
![D2 RTL Viewer](figures/rtl_viewer_D2.png)

### D3: Parallel RTL Schematic
![D3 RTL Viewer](figures/rtl_viewer_D3.png)

### D4: Pipelined + Parallel RTL Schematic
![D4 RTL Viewer](figures/rtl_viewer_D4.png)

### DSP Block Inference (D1/D2)
![Technology Map DSP](figures/tech_map_dsp.png)

### Parallel DSP Block Inference (D3/D4)
![Technology Map DSP Parallel](figures/tech_map_dsp_parallel.png)
