# 4. Hardware Synthesis Results

## Target Device
- **FPGA**: Intel Cyclone V (5CGXFC7C7F23C8)
- **Tool**: Quartus Prime Lite 20.1.1
- **Clock Constraint**: 100 MHz (10 ns period)
- **Note**: Fmax = 1000 / (T\_period - slack). All designs analyzed with 100 MHz constraint.

## Resource Utilization & Performance

| Architecture | ALMs | DSPs | Fmax (MHz) | Throughput (MSPS)* | Power (mW) | Power Eff. (mW/MSPS) | Area Eff. (MSPS/kALM) | Status |
|---|---|---|---|---|---|---|---|---|
| Direct-Form | 2003 | 156 | 34.1 | **34.1** | 122.56 | 3.59 | 17.02 | ✅ OK |
| Pipelined | 2176 | 131 | 59.1 | **59.1** | 91.40 | 1.55 | 27.16 | ✅ OK |
| L=2 Parallel | 14119 | 156 | 36.8 | **73.6** | 227.98 | 3.10 | 5.21 | ✅ OK |
| L=3 Parallel | 24726 | 156 | 35.4 | **106.2** | 354.13 | 3.33 | 4.30 | ✅ OK |
| L=2 Fast FIR | 18785 | 0 | 35.4 | **70.8** | 201.87 | 2.85 | 3.77 | ✅ OK |
| L=3 Fast FIR | 25604 | 0 | 35.0 | **105.0** | 302.06 | 2.88 | 4.10 | ✅ OK |
| L=3 Pipelined Fast FIR | 14374 | 156 | 57.6 | **172.8** | 132.08 | 0.76 | 12.02 | ✅ OK |

### Metric Definitions

- **Throughput (MSPS)**: *Mega Samples Per Second*. Computed as `Fmax * L`, where `L` is the number of samples processed per cycle.
- **Power Efficiency (mW/MSPS)**: Energy cost per sample. Lower is better.
- **Area Efficiency (MSPS/kALM)**: High-speed throughput density. Higher is better.

## Final Observations

1. **Pipelining Advantage**: Pipelining the direct-form architecture nearly doubled MSPS (~34 to ~59) with only ~8% area overhead, creating a much more efficient hardware profile.
2. **Parallel Scaling Bottleneck**: Standard parallelization (L=2, L=3) increases MSPS but at a severe cost to **Area Efficiency**. MSPS/kALM drops from ~17.0 (Direct) to ~1.4 (L=3 Parallel) because the core MAC tree is repeated without reducing complexity.
3. **Optimization Winner**: The **L=3 Pipelined Fast FIR** is the project's optimal design. It achieves the highest throughput (**172 MSPS**) while consuming less power than any other parallel design and maintaining the best power efficiency (**0.77 mW/MSPS**).

---
*Final Results - Compiled on Wed Mar 25 21:17:31 EDT 2026*
