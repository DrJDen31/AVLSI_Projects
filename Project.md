## Course Project: FIR Filter Design and Implementation
Due date: March 24th

### Description
The objective of this course project is to design and implement low-pass FIR filter. Using Matlab to construct a 100-
tap low-pass filter with the transition region of 0.2p~0.23p rad/sample and stopband attenuation of at least 80dB
(you may increase the number of filter taps if necessary). Refer to https://www.mathworks.com/help/signal/ug/fir-filter-design.html for detailed Matlab document. Decide the quantization of filter coefficients and
input/output/intermediate data on your own. For the hardware implementation, the design entry can be either
Verilog or VHDL, though Verilog is preferred due to its popularity in the industry. As we discussed earlier, you may
use Xilinx/Altera FPGA design environment or Synopsys Design Compiler. For the FIR filter architecture, consider (i)
pipelining, (2) reduced-complexity parallel processing (L=2 and L=3), and (3) combined pipelining and L=3 parallel
processing.
Create a Github site for this design project and your final open-ended design project. Other than the source code,
your Github site should contain at least the following information with corresponding weights on grading:
- (20%) Description of the use of Matlab for FIR filter design and the structure of your Verilog code
- (20%) Filter frequency response of the original (un-quantized) filter and quantized filter,
comments/thoughts about the quantization effect, and anything you did to deal with overflow
- (20%) Architecture of your pipelined and/or parallelized FIR filter
- (20%) Detailed hardware implementation results (e.g., area, clock frequency, power estimation)
- (20%) Further analysis and conclusion
You should prepare your Github site by assuming your future hiring manager may have a look at it as a reference.