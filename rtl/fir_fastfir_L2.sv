`timescale 1ns / 1ps

import coeff_pkg::*;

module fir_fastfir_L2 (
    input  logic                 clk,
    input  logic                 rst_n,
    
    input  logic                 valid_in,
    input  logic signed [DATA_W-1:0] data_in_0, // x[2k]
    input  logic signed [DATA_W-1:0] data_in_1, // x[2k+1]
    
    output logic                 valid_out,
    output logic signed [DATA_W-1:0] data_out_0, // y[2k]
    output logic signed [DATA_W-1:0] data_out_1  // y[2k+1]
);

    // L=2 Fast FIR Algorithm (Reduced Complexity)
    // Equations:
    // H0' = H0
    // H1' = H1
    // H2' = H0 + H1
    
    // Y0 = H0'*x0 + z^-1(H1'*x1)
    // Y1 = H2'*(x0+x1) - H0'*x0 - H1'*x1
    
    // Subfilter outputs:
    // P0 = H0 * x0
    // P1 = H1 * x1
    // P2 = (H0 + H1) * (x0 + x1)
    
    // Final outputs:
    // y0 = P0 + z^-1(P1)
    // y1 = P2 - P0 - P1
    
    // This requires 3 subfilters per tap instead of 4 (in the simple parallel).
    // Specifically, for an N-tap filter, it takes 3 * (N/2) = 1.5N multiplications
    // instead of 2N multiplications.
    
    localparam int MULT_W = DATA_W + COEFF_W + 1; // +1 bit for pre-addition
    localparam int L2_TAPS = (N_TAPS + 1) / 2;
    
    // Pre-calculated coefficients
    logic signed [COEFF_W-1:0] h0 [0:L2_TAPS-1];
    logic signed [COEFF_W-1:0] h1 [0:L2_TAPS-1];
    logic signed [COEFF_W:0]   h0_plus_h1 [0:L2_TAPS-1]; // Note: COEFF_W+1 width
    
    initial begin
        for(int i=0; i<N_TAPS; i++) begin
            if (i % 2 == 0) h0[i/2] = COEFFS[i];
            else            h1[i/2] = COEFFS[i];
        end
        if (N_TAPS % 2 != 0) h1[L2_TAPS-1] = '0;
        
        for(int i=0; i<L2_TAPS; i++) begin
            h0_plus_h1[i] = h0[i] + h1[i];
        end
    end
    
    // Delay lines
    logic signed [DATA_W-1:0] dl_x0 [0:L2_TAPS-1];
    logic signed [DATA_W-1:0] dl_x1 [0:L2_TAPS-1];
    
    // Pre-addition delay line: x0 + x1
    logic signed [DATA_W:0] dl_x0_plus_x1 [0:L2_TAPS-1]; // DATA_W+1 width
    
    // z^-1 delay for P1 (delayed subfilter output)
    logic signed [ACC_W-1:0] acc_p1_delayed;
    
    logic valid_p1;

    // Shift Registers
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < L2_TAPS; i++) begin
                dl_x0[i] <= '0;
                dl_x1[i] <= '0;
                dl_x0_plus_x1[i] <= '0;
            end
            valid_p1 <= 1'b0;
            acc_p1_delayed <= '0;
        end else begin
            valid_p1 <= valid_in;
            if (valid_in) begin
                dl_x0[0] <= data_in_0;
                dl_x1[0] <= data_in_1;
                dl_x0_plus_x1[0] <= data_in_0 + data_in_1;
                
                for (int i = 1; i < L2_TAPS; i++) begin
                    dl_x0[i] <= dl_x0[i-1];
                    dl_x1[i] <= dl_x1[i-1];
                    dl_x0_plus_x1[i] <= dl_x0_plus_x1[i-1];
                end
            end
            
            // z^-1 delay is on the full accumulated Subfilter 1 output
            // (combinational logic calculates acc_p1 below)
        end
    end

    // Subfilter Combinational MAC
    logic signed [MULT_W-1:0] m_p0;
    logic signed [MULT_W-1:0] m_p1;
    logic signed [DATA_W+COEFF_W+1:0] m_p2; // Multiplier is (DATA_W+1)*(COEFF_W+1)
    
    logic signed [ACC_W-1:0] acc_p0;
    logic signed [ACC_W-1:0] acc_p1;
    logic signed [ACC_W-1:0] acc_p2;
    
    always_comb begin
        acc_p0 = '0;
        acc_p1 = '0;
        acc_p2 = '0;
        
        for (int i = 0; i < L2_TAPS; i++) begin
            m_p0 = dl_x0[i] * h0[i];
            m_p1 = dl_x1[i] * h1[i];
            m_p2 = dl_x0_plus_x1[i] * h0_plus_h1[i];
            
            acc_p0 = acc_p0 + {{ (ACC_W - MULT_W){m_p0[MULT_W-1]} }, m_p0};
            acc_p1 = acc_p1 + {{ (ACC_W - MULT_W){m_p1[MULT_W-1]} }, m_p1};
            acc_p2 = acc_p2 + {{ (ACC_W - (DATA_W+COEFF_W+2)){m_p2[DATA_W+COEFF_W+1]} }, m_p2};
        end
    end

    // Sequential update for z^-1(P1)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) acc_p1_delayed <= '0;
        else if (valid_in) acc_p1_delayed <= acc_p1;
    end

    // Post-addition network and Output
    logic signed [ACC_W-1:0] acc_y0, acc_y1;
    localparam int COEFF_FRAC_BITS = COEFF_W - 1;
    
    always_comb begin
        // y0 = P0 + z^-1(P1)
        acc_y0 = acc_p0 + acc_p1_delayed;
        
        // y1 = P2 - P0 - P1
        acc_y1 = acc_p2 - acc_p0 - acc_p1;
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out_0 <= '0;
            data_out_1 <= '0;
            valid_out  <= 1'b0;
        end else begin
            valid_out <= valid_p1;
            if (valid_p1) begin
                data_out_0 <= acc_y0[COEFF_FRAC_BITS +: DATA_W];
                data_out_1 <= acc_y1[COEFF_FRAC_BITS +: DATA_W];
            end
        end
    end

endmodule
