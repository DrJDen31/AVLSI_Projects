# 5. Result Analysis and Conclusion

## Performance Trade-Off Analysis

### 1. The Cost of Throughput (Direct vs Simple Parallel)
The simplest way to achieve a higher throughput ($L$ samples per clock cycle) is the simple polyphase decomposition network mapping (`fir_parallel_L2.sv` and `fir_parallel_L3.sv`). 

While this mathematically guarantees exact $L \times$ performance scaling, the hardware cost scales proportionally. The $L=3$ parallel FIR requires $3N=525$ multipliers. On resource-constrained FPGAs or ASICs, routing and logic utilization quickly become the bottleneck before thermal limits are even reached.

### 2. The Multiplier Savings of Fast FIR
By employing the Fast FIR mathematically reduced-complexity algorithm (`fir_fastfir_L2.sv` and `L3.sv`), we traded additive complexity for multiplicative complexity. 

* **The Trade-off**: We introduced significant combinational pre-addition networks ($x_0 + x_1$) and post-addition reconstruction networks ($P_4 - P_1 - P_2$). Adders are extremely cheap in hardware (1 LUT per bit) compared to multipliers (DSP blocks or large LUT arrays).
* **The Result**: For $L=3$, we successfully reduced the required subfilters from 9 to 6. This cuts the DSP block utilization by **33.3%** While routing complexity increases slightly due to the cross-addition networks, the Area-Delay Product (ADP) heavily favors the Fast FIR architecture over simple parallel architectures.

### 3. Pipelining for Fmax (Direct vs Pipelined)
The direct-form FIR (`fir_direct.sv`) and all the parallel variants suffer from a significant timing bottleneck: the long combinational adder sequence accumulating the $N=175$ tap multiplications. 

The pipelined FIR (`fir_pipelined.sv`) breaks this critical path by inserting pipeline registers. 
* **The Trade-off**: This drastically increases Register (flip-flop) usage and increases the output latency.
* **The Result**: The Maximum Clock Frequency ($F_{max}$) increases dramatically. By targeting a pipeline depth of $M=4$ taps per stage, the critical path is reduced to a single DSP multiplication and a small 4-input adder tree, allowing the design to easily meet the 100 MHz target constraint. 

## Architectural Conclusions
The **Combined Pipelining + Fast FIR L=3 (`fir_pipe_fastfir_L3.sv`)** represents the pinnacle of these optimizations. 

By taking the mathematically reduced 6-subfilter $L=3$ structure and applying the pipelined cut-set to the accumulator trees, we achieve the highest possible algorithmic throughput ($3 \times F_{max}$ Msps) while maintaining a fast clock and saving 33% of the dedicated multiplier resources. This is the recommended architecture for high-performance DSP applications where area and throughput are the dominant design constraints.
