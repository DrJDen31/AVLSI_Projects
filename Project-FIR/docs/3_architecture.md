# 3. FIR Filter Architecture Designs

This section details the 7 architectural variants designed in SystemVerilog. All architectures operate on $N=175$ taps with 16-bit input and 23-bit coefficient widths, utilizing a 49-bit internal accumulator.

## 3.1 Direct-Form Baseline (`fir_direct.sv`)
The baseline design implements the standard convolution sum directly. It consists of an $N$-stage shift register delay line (the $z^{-1}$ elements). In a single clock cycle, all $N$ buffered samples are multiplied by their respective coefficients $h[n]$ and summed in a combinational tree.
* **Latency:** 1 cycle (for the input register)
* **Throughput:** 1 sample/cycle
* **Multipliers:** $N = 175$

## 3.2 Pipelined FIR (`fir_pipelined.sv`)
To break the long combinatorial critical path of the 175-input adder tree, pipeline registers were introduced. The pipeline interrupts the accumulation chain every $M=4$ taps (parameterized via `PIPE_EVERY`).
The partial sums of each 4-tap chunk are computed combinationally, added to the accumulated sum from the previous pipeline stage, and registered.
* **Latency:** $1 + \lceil N/M \rceil = 45$ cycles
* **Throughput:** 1 sample/cycle
* **Multipliers:** $N = 175$

## 3.3 Simple Parallel processing ($L=2$ and $L=3$)
Simple block processing increases the throughput to $L$ samples per clock cycle by utilizing traditional polyphase decomposition.
* $H(z) = H_0(z^2) + z^{-1}H_1(z^2)$ for $L=2$
* $H(z) = H_0(z^3) + z^{-1}H_1(z^3) + z^{-2}H_2(z^3)$ for $L=3$

While this achieves the $L \times$ throughput specification, it requires duplicating hardware indiscriminately. 
* **`fir_parallel_L2` Multipliers:** $2N = 350$
* **`fir_parallel_L3` Multipliers:** $3N = 525$

## 3.4 Reduced-Complexity Fast FIR algorithm ($L=2$ and $L=3$)
To reduce the exorbitant multiplier cost of simple parallel processing, the Fast FIR algorithm was implemented.

### $L=2$ Fast FIR (`fir_fastfir_L2.sv`)
Instead of computing the 4 subfilters of the simple $L=2$ structure, Fast FIR computes 3 subfilters using pre-addition networks ($x_0 + x_1$) and post-addition reconstruction networks.
* **Savings:** Reduces multiplier count from $2N$ (350) down to $1.5N$ (263).

### $L=3$ Fast FIR (`fir_fastfir_L3.sv`)
For $L=3$, the 9 subfilters required for simple block processing are mathematically reduced to 6 subfilters.
* $P_0 = H_0X_0$, $P_1 = H_1X_1$, $P_2 = H_2X_2$
* $P_3 = (H_0+H_1)(X_0+X_1)$, $P_4 = (H_1+H_2)(X_1+X_2)$, $P_5 = (H_0+H_2)(X_0+X_2)$
* **Savings:** Reduces multiplier count from $3N$ (525) down to $2N$ (350).

## 3.5 Combined Pipelining and $L=3$ Fast FIR (`fir_pipe_fastfir_L3.sv`)
The most complex architecture combines the $L=3$ Fast FIR multiplier optimization with the $M=4$ pipelining technique. It implements the 6 reduced subfilters but pipelines their internal accumulation paths. Delayed terms ($z^{-1}$) are carefully synchronized with the pipeline `valid_sr` shift register to ensure data causality in the post-addition network.
* **Latency:** $1 + \lceil N/(3\times M) \rceil = 16$ cycles
* **Throughput:** 3 samples/cycle
* **Multipliers:** $2N = 350$
