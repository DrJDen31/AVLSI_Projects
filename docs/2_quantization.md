# 2. Frequency Response & Quantization

## Quantization Effects Analysis
Digital FIR filters require fixed-point arithmetic instead of continuous floating-point values. Our coefficients must be quantized into a finite bit width. As bit width decreases, the filter's frequency response degrades, potentially violating the 80 dB stopband specification.

To find the optimal coefficient width, we swept through a range of fractional bits. Since the absolute value of all ideal coefficients is less than 1.0, we allocated **0 integer bits and 1 sign bit**, making the coefficient purely fractional.

| Fractional Bits | Attenuation (dB) | Status |
|---|---|---|
| 8 | 25.32 | FAIL |
| 12 | 51.13 | FAIL |
| 16 | 72.63 | FAIL |
| 20 | 79.52 | FAIL |
| 22 | 80.18 | **PASS** |

Our analysis showed that **22 fractional bits** were the minimum required to re-attain the 80 dB attenuation post-quantization. With 1 sign bit, this gives a total coefficient width of **23 bits (format Q0.22).**

## Overflow Prevention
FIR convolutions sum the products of input data and coefficients. Without proper bit-width accounting, this summation will overflow the arithmetic accumulator.

The maximum possible growth in an N-tap FIR filter is bounded by:
$$ \text{Guard Bits} = \lceil\log_2\left(\sum_{i=0}^{N-1} |h[i]|\right)\rceil $$

Our analysis yielded:
* **Input Width:** 16 bits (Q0.15 signed)
* **Coefficient Width:** 23 bits (Q0.22 signed)
* **Multiplier Output Width:** 39 bits (Q1.37 signed)
* **Guard Bits:** 2 bits (calculated from the absolute sum of the 175 taps)
* **Final Accumulator Width:** 49 bits $(39 + \lceil\log_2(175)\rceil + 2)$

Operating internally with a 49-bit accumulator mathematically guarantees that overflow will never occur, regardless of the input data sequence. At the output stage, we slice the accumulator to extract the 16 most significant fractional bits, discarding the lower 22 bits contributed by the fractional coefficients.
