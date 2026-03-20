`timescale 1ns / 1ps

import coeff_pkg::*; // Import N_TAPS, COEFF_W, DATA_W, ACC_W, and COEFFS array

module fir_direct (
    input  logic                 clk,
    input  logic                 rst_n,
    
    // Data in
    input  logic                 valid_in,
    input  logic signed [DATA_W-1:0] data_in,
    
    // Data out
    output logic                 valid_out,
    output logic signed [DATA_W-1:0] data_out
);

    // Pipeline registers for input data (the delay line)
    // We need N_TAPS registers to store the history of inputs
    logic signed [DATA_W-1:0] delay_line [0:N_TAPS-1];
    
    // Multiplier outputs
    // Size = DATA_W + COEFF_W
    localparam int MULT_W = DATA_W + COEFF_W;
    logic signed [MULT_W-1:0] mult_out [0:N_TAPS-1];
    
    // Shift register for valid signal to match latency
    // In this direct form, combinatorial accumulation happens in the same cycle 
    // as the multiplication, so valid_out is just valid_in delayed by 1 cycle
    // to account for the input registering.
    logic valid_p1;

    // 1. Shift Register (Delay Line)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < N_TAPS; i++) begin
                delay_line[i] <= '0;
            end
            valid_p1 <= 1'b0;
        end else begin
            valid_p1 <= valid_in;
            if (valid_in) begin
                delay_line[0] <= data_in;
                for (int i = 1; i < N_TAPS; i++) begin
                    delay_line[i] <= delay_line[i-1];
                end
            end
        end
    end

    // 2. Multipliers (Combinational)
    always_comb begin
        for (int i = 0; i < N_TAPS; i++) begin
            mult_out[i] = delay_line[i] * COEFFS[i];
        end
    end

    // 3. Accumulator Tree (Combinational in direct form)
    // Using a simple for-loop accumulator
    logic signed [ACC_W-1:0] acc_sum;
    
    always_comb begin
        acc_sum = '0;
        for (int i = 0; i < N_TAPS; i++) begin
            // Sign extend the multiplier output to the accumulator width
            // and add it to the running sum
            acc_sum = acc_sum + {{ (ACC_W - MULT_W){mult_out[i][MULT_W-1]} }, mult_out[i]};
        end
    end

    // 4. Output Stage
    // We slice the accumulator to get the final output.
    // The accumulator has `acc_frac_bits` (which equals `input_frac_bits + coeff_frac_bits`).
    // The output needs `input_frac_bits`.
    // So we right-shift (slice) by `coeff_frac_bits`.
    
    // From our MATLAB script:
    // data_in  is Q0.15 (16 bits) -> 15 frac bits
    // COEFFS is Qsomething.22 -> 22 frac bits
    // ACC_W  is 49 bits. Frac bits = 15 + 22 = 37.
    // We want the output to be Qsomething.15. So we drop the bottom 22 bits.
    // And take the next 16 bits.
    
    localparam int COEFF_FRAC_BITS = COEFF_W - 1; // Assuming 0 integer bits, 1 sign bit
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out  <= '0;
            valid_out <= 1'b0;
        end else begin
            valid_out <= valid_p1;
            // Rounding: add half of the LSB of the truncated part
            // Simple truncation for now, but taking the correct slice:
            // [ COEFF_FRAC_BITS + DATA_W - 1 : COEFF_FRAC_BITS ]
            
            // Example:
            // If acc is 49 bits, COEFF_W is 23 (22 frac). DATA_W is 16.
            // Slice is acc_sum[ 22 + 16 - 1 : 22 ] = acc_sum[37:22]
            
            if (valid_p1) begin
                data_out <= acc_sum[COEFF_FRAC_BITS +: DATA_W];
            end
        end
    end

endmodule
