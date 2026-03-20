`timescale 1ns / 1ps

import coeff_pkg::*;

module fir_parallel_L3 (
    input  logic                 clk,
    input  logic                 rst_n,
    
    input  logic                 valid_in,
    // Accepts 3 samples per clock cycle
    input  logic signed [DATA_W-1:0] data_in_0, // x[3k]
    input  logic signed [DATA_W-1:0] data_in_1, // x[3k+1]
    input  logic signed [DATA_W-1:0] data_in_2, // x[3k+2]
    
    output logic                 valid_out,
    // Outputs 3 samples per clock cycle
    output logic signed [DATA_W-1:0] data_out_0, // y[3k]
    output logic signed [DATA_W-1:0] data_out_1, // y[3k+1]
    output logic signed [DATA_W-1:0] data_out_2  // y[3k+2]
);

    // Simple L=3 Polyphase Decomposition
    // H(z) = H0(z^3) + z^-1 H1(z^3) + z^-2 H2(z^3)
    
    // y0 = H0*x0 + z^-1(H1)*x2 + z^-1(H2)*x1
    // y1 = H0*x1 + H1*x0 + z^-1(H2)*x2
    // y2 = H0*x2 + H1*x1 + H2*x0
    
    localparam int MULT_W = DATA_W + COEFF_W;
    localparam int L3_TAPS = (N_TAPS + 2) / 3; // Ceil division
    
    // Polyphase coefficients
    logic signed [COEFF_W-1:0] h0 [0:L3_TAPS-1];
    logic signed [COEFF_W-1:0] h1 [0:L3_TAPS-1];
    logic signed [COEFF_W-1:0] h2 [0:L3_TAPS-1];
    
    initial begin
        for(int i=0; i<N_TAPS; i++) begin
            if      (i % 3 == 0) h0[i/3] = COEFFS[i];
            else if (i % 3 == 1) h1[i/3] = COEFFS[i];
            else                 h2[i/3] = COEFFS[i];
        end
        // Pad with zeros if necessary
        if ((N_TAPS % 3) == 1) begin
            h1[L3_TAPS-1] = '0;
            h2[L3_TAPS-1] = '0;
        end else if ((N_TAPS % 3) == 2) begin
            h2[L3_TAPS-1] = '0;
        end
    end
    
    // Delay lines 
    logic signed [DATA_W-1:0] dl_x0 [0:L3_TAPS-1];
    logic signed [DATA_W-1:0] dl_x1 [0:L3_TAPS-1];
    logic signed [DATA_W-1:0] dl_x2 [0:L3_TAPS-1];
    
    // Delayed versions for z^-1 terms
    logic signed [DATA_W-1:0] dl_x1_delayed [0:L3_TAPS-1];
    logic signed [DATA_W-1:0] dl_x2_delayed [0:L3_TAPS-1];
    
    logic valid_p1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < L3_TAPS; i++) begin
                dl_x0[i] <= '0; dl_x1[i] <= '0; dl_x2[i] <= '0;
                dl_x1_delayed[i] <= '0; dl_x2_delayed[i] <= '0;
            end
            valid_p1 <= 1'b0;
        end else begin
            valid_p1 <= valid_in;
            if (valid_in) begin
                dl_x0[0] <= data_in_0;
                dl_x1[0] <= data_in_1;
                dl_x2[0] <= data_in_2;
                
                dl_x1_delayed[0] <= dl_x1[0];
                dl_x2_delayed[0] <= dl_x2[0];
                
                for (int i = 1; i < L3_TAPS; i++) begin
                    dl_x0[i] <= dl_x0[i-1];
                    dl_x1[i] <= dl_x1[i-1];
                    dl_x2[i] <= dl_x2[i-1];
                    
                    dl_x1_delayed[i] <= dl_x1_delayed[i-1];
                    dl_x2_delayed[i] <= dl_x2_delayed[i-1];
                end
            end
        end
    end

    logic signed [ACC_W-1:0] acc_y0, acc_y1, acc_y2;
    
    always_comb begin
        acc_y0 = '0; acc_y1 = '0; acc_y2 = '0;
        
        for (int i = 0; i < L3_TAPS; i++) begin
            // Multiplications (9 per macro-tap)
            logic signed [MULT_W-1:0] m_h0_x0 = dl_x0[i] * h0[i];
            logic signed [MULT_W-1:0] m_h1_x2_d = dl_x2_delayed[i] * h1[i];
            logic signed [MULT_W-1:0] m_h2_x1_d = dl_x1_delayed[i] * h2[i];
            
            logic signed [MULT_W-1:0] m_h0_x1 = dl_x1[i] * h0[i];
            logic signed [MULT_W-1:0] m_h1_x0 = dl_x0[i] * h1[i];
            logic signed [MULT_W-1:0] m_h2_x2_d = dl_x2_delayed[i] * h2[i];
            
            logic signed [MULT_W-1:0] m_h0_x2 = dl_x2[i] * h0[i];
            logic signed [MULT_W-1:0] m_h1_x1 = dl_x1[i] * h1[i];
            logic signed [MULT_W-1:0] m_h2_x0 = dl_x0[i] * h2[i];
            
            // Accumulate y0 = H0*x0 + z^-1(H1)*x2 + z^-1(H2)*x1
            acc_y0 = acc_y0 + {{ (ACC_W - MULT_W){m_h0_x0[MULT_W-1]} }, m_h0_x0} 
                            + {{ (ACC_W - MULT_W){m_h1_x2_d[MULT_W-1]} }, m_h1_x2_d}
                            + {{ (ACC_W - MULT_W){m_h2_x1_d[MULT_W-1]} }, m_h2_x1_d};
                            
            // Accumulate y1 = H0*x1 + H1*x0 + z^-1(H2)*x2
            acc_y1 = acc_y1 + {{ (ACC_W - MULT_W){m_h0_x1[MULT_W-1]} }, m_h0_x1} 
                            + {{ (ACC_W - MULT_W){m_h1_x0[MULT_W-1]} }, m_h1_x0}
                            + {{ (ACC_W - MULT_W){m_h2_x2_d[MULT_W-1]} }, m_h2_x2_d};
                            
            // Accumulate y2 = H0*x2 + H1*x1 + H2*x0
            acc_y2 = acc_y2 + {{ (ACC_W - MULT_W){m_h0_x2[MULT_W-1]} }, m_h0_x2} 
                            + {{ (ACC_W - MULT_W){m_h1_x1[MULT_W-1]} }, m_h1_x1}
                            + {{ (ACC_W - MULT_W){m_h2_x0[MULT_W-1]} }, m_h2_x0};
        end
    end

    localparam int COEFF_FRAC_BITS = COEFF_W - 1;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out_0 <= '0; data_out_1 <= '0; data_out_2 <= '0;
            valid_out  <= 1'b0;
        end else begin
            valid_out <= valid_p1;
            if (valid_p1) begin
                data_out_0 <= acc_y0[COEFF_FRAC_BITS +: DATA_W];
                data_out_1 <= acc_y1[COEFF_FRAC_BITS +: DATA_W];
                data_out_2 <= acc_y2[COEFF_FRAC_BITS +: DATA_W];
            end
        end
    end

endmodule
