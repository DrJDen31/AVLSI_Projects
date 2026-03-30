# 4. Hardware Synthesis Results

## Target Device
- **FPGA**: Intel Cyclone V (5CGXFC7C7F23C8)
- **Tool**: Quartus Prime Lite 20.1.1
- **Note**: Fmax is calculated based on the worst-case setup slack during timing analysis. All designs were evaluated using the same timing model for consistency.

## Resource Utilization & Performance

| Architecture | ALMs | DSPs | Fmax (MHz) | Throughput (MSPS)* | Power (mW) | Power Eff. (mW/MSPS) | Area Eff. (MSPS/kALM) | Status |
|---|---|---|---|---|---|---|---|---|
| Direct-Form | 2003 | 156 | 34.1 | **34.1** | 122.56 | 3.59 | 17.02 | ✅ OK |
| Pipelined | 2016 | 131 | 68.9 | **68.9** | 93.02 | 1.35 | 34.18 | ✅ OK |
| L=2 Parallel | 14119 | 156 | 36.8 | **73.6** | 227.98 | 3.10 | 5.21 | ✅ OK |
| L=3 Parallel | 24726 | 156 | 35.4 | **106.2** | 354.13 | 3.33 | 4.30 | ✅ OK |
| L=2 Fast FIR | 18785 | 0 | 35.4 | **70.8** | 201.87 | 2.85 | 3.77 | ✅ OK |
| L=3 Fast FIR | 25604 | 0 | 35.0 | **105.0** | 302.06 | 2.88 | 4.10 | ✅ OK |
| L=3 Pipelined Fast FIR | 14270 | 156 | 68.4 | **205.2** | 137.37 | 0.67 | 14.38 | ✅ OK |

### Metric Definitions

- **Throughput (MSPS)**: *Mega Samples Per Second*. Computed as `Fmax * L`, where `L` is the number of samples processed per cycle.
- **Power Efficiency (mW/MSPS)**: Energy cost per sample. Lower is better.
- **Area Efficiency (MSPS/kALM)**: High-speed throughput density. Higher is better.

## Final Observations

1. **Pipelining Advantage**: Pipelining the direct-form architecture nearly doubled Fmax (~34 to ~69 MHz) with negligible area overhead, creating a much more efficient hardware profile.
2. **Parallel Scaling Bottleneck**: Standard parallelization (L=2, L=3) increases MSPS but at a severe cost to **Area Efficiency**. MSPS/kALM drops significantly because the core logic is repeated without structural reduction.
3. **Optimization Winner**: The **L=3 Pipelined Fast FIR** is the project's optimal design. It achieves the highest throughput (**205.2 MSPS**) while maintaining high power efficiency (**0.67 mW/MSPS**) and leveraging pipelining to overcome the clock speed limitations of parallel structures.

---
*Final Results - Compiled on Mon Mar 30 01:19:11 EDT 2026*
