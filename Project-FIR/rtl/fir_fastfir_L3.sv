import coeff_pkg::*;

module fir_fastfir_L3 (
    input  logic                 clk,
    input  logic                 rst_n,
    
    input  logic                 valid_in,
    input  logic signed [DATA_W-1:0] data_in_0, // x[3k]
    input  logic signed [DATA_W-1:0] data_in_1, // x[3k+1]
    input  logic signed [DATA_W-1:0] data_in_2, // x[3k+2]
    
    output logic                 valid_out,
    output logic signed [DATA_W-1:0] data_out_0, // y[3k]
    output logic signed [DATA_W-1:0] data_out_1, // y[3k+1]
    output logic signed [DATA_W-1:0] data_out_2  // y[3k+2]
);

    // L=3 Fast FIR Algorithm (Reduced Complexity)
    // Decomposes 9 subfilters into 6 subfilters.
    // Savings: 3N multiplications -> 6 * (N/3) = 2N multiplications.
    
    // Original polynomials: H0, H1, H2 and X0, X1, X2
    // Fast FIR subfilters:
    // P0 = H0 * X0
    // P1 = H1 * X1
    // P2 = H2 * X2
    // P3 = (H0 + H1) * (X0 + X1)
    // P4 = (H1 + H2) * (X1 + X2)
    // P5 = (H0 + H2) * (X0 + X2)
    
    // Outputs (using z = z^-1 of the subfilter rate, i.e., z^-3 of sample rate):
    // Y0 = P0 + z * (P4 - P1 - P2)
    // Y1 = P3 - P0 - P1 + z * P2
    // Y2 = P5 - P0 - P2 + P1
    
    localparam int MULT_W = DATA_W + COEFF_W + 1;
    localparam int L3_TAPS = (N_TAPS + 2) / 3;
    
    // Coefficients
    logic signed [COEFF_W-1:0] h0 [0:L3_TAPS-1];
    logic signed [COEFF_W-1:0] h1 [0:L3_TAPS-1];
    logic signed [COEFF_W-1:0] h2 [0:L3_TAPS-1];
    
    logic signed [COEFF_W:0] h0_p_h1 [0:L3_TAPS-1];
    logic signed [COEFF_W:0] h1_p_h2 [0:L3_TAPS-1];
    logic signed [COEFF_W:0] h0_p_h2 [0:L3_TAPS-1];
    
    initial begin
        for(int i=0; i<N_TAPS; i++) begin
            if      (i % 3 == 0) h0[i/3] = COEFFS[i];
            else if (i % 3 == 1) h1[i/3] = COEFFS[i];
            else                 h2[i/3] = COEFFS[i];
        end
        if ((N_TAPS % 3) == 1) begin
            h1[L3_TAPS-1] = '0; h2[L3_TAPS-1] = '0;
        end else if ((N_TAPS % 3) == 2) begin
            h2[L3_TAPS-1] = '0;
        end
        
        for(int i=0; i<L3_TAPS; i++) begin
            h0_p_h1[i] = h0[i] + h1[i];
            h1_p_h2[i] = h1[i] + h2[i];
            h0_p_h2[i] = h0[i] + h2[i];
        end
    end
    
    // Delay lines
    logic signed [DATA_W-1:0] dl_x0 [0:L3_TAPS-1];
    logic signed [DATA_W-1:0] dl_x1 [0:L3_TAPS-1];
    logic signed [DATA_W-1:0] dl_x2 [0:L3_TAPS-1];
    
    logic signed [DATA_W:0] dl_x0_p_x1 [0:L3_TAPS-1];
    logic signed [DATA_W:0] dl_x1_p_x2 [0:L3_TAPS-1];
    logic signed [DATA_W:0] dl_x0_p_x2 [0:L3_TAPS-1];
    
    logic valid_p1;

    // Shift Registers
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < L3_TAPS; i++) begin
                dl_x0[i] <= '0; dl_x1[i] <= '0; dl_x2[i] <= '0;
                dl_x0_p_x1[i] <= '0; dl_x1_p_x2[i] <= '0; dl_x0_p_x2[i] <= '0;
            end
            valid_p1 <= 1'b0;
        end else begin
            valid_p1 <= valid_in;
            if (valid_in) begin
                dl_x0[0] <= data_in_0; dl_x1[0] <= data_in_1; dl_x2[0] <= data_in_2;
                dl_x0_p_x1[0] <= data_in_0 + data_in_1;
                dl_x1_p_x2[0] <= data_in_1 + data_in_2;
                dl_x0_p_x2[0] <= data_in_0 + data_in_2;
                
                for (int i = 1; i < L3_TAPS; i++) begin
                    dl_x0[i] <= dl_x0[i-1]; dl_x1[i] <= dl_x1[i-1]; dl_x2[i] <= dl_x2[i-1];
                    dl_x0_p_x1[i] <= dl_x0_p_x1[i-1];
                    dl_x1_p_x2[i] <= dl_x1_p_x2[i-1];
                    dl_x0_p_x2[i] <= dl_x0_p_x2[i-1];
                end
            end
        end
    end

    // Subfilter Combinational MAC
    logic signed [MULT_W-1:0] m_p0, m_p1, m_p2;
    logic signed [DATA_W+COEFF_W+1:0] m_p3, m_p4, m_p5;
    
    logic signed [ACC_W-1:0] acc_p0, acc_p1, acc_p2, acc_p3, acc_p4, acc_p5;
    
    always_comb begin
        acc_p0 = '0; acc_p1 = '0; acc_p2 = '0;
        acc_p3 = '0; acc_p4 = '0; acc_p5 = '0;
        
        for (int i = 0; i < L3_TAPS; i++) begin
            m_p0 = dl_x0[i] * h0[i];
            m_p1 = dl_x1[i] * h1[i];
            m_p2 = dl_x2[i] * h2[i];
            
            m_p3 = dl_x0_p_x1[i] * h0_p_h1[i];
            m_p4 = dl_x1_p_x2[i] * h1_p_h2[i];
            m_p5 = dl_x0_p_x2[i] * h0_p_h2[i];
            
            acc_p0 = acc_p0 + {{ (ACC_W - MULT_W){m_p0[MULT_W-1]} }, m_p0};
            acc_p1 = acc_p1 + {{ (ACC_W - MULT_W){m_p1[MULT_W-1]} }, m_p1};
            acc_p2 = acc_p2 + {{ (ACC_W - MULT_W){m_p2[MULT_W-1]} }, m_p2};
            
            acc_p3 = acc_p3 + {{ (ACC_W - (DATA_W+COEFF_W+2)){m_p3[DATA_W+COEFF_W+1]} }, m_p3};
            acc_p4 = acc_p4 + {{ (ACC_W - (DATA_W+COEFF_W+2)){m_p4[DATA_W+COEFF_W+1]} }, m_p4};
            acc_p5 = acc_p5 + {{ (ACC_W - (DATA_W+COEFF_W+2)){m_p5[DATA_W+COEFF_W+1]} }, m_p5};
        end
    end

    // Sequential update for z^-1 delayed terms
    logic signed [ACC_W-1:0] acc_p1_d, acc_p2_d, acc_p4_d;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_p1_d <= '0; acc_p2_d <= '0; acc_p4_d <= '0;
        end else if (valid_in) begin // Or valid_p1 depending on exact valid pipeline match
            acc_p1_d <= acc_p1;
            acc_p2_d <= acc_p2;
            acc_p4_d <= acc_p4;
        end
    end

    // Post-addition network
    logic signed [ACC_W-1:0] acc_y0, acc_y1, acc_y2;
    localparam int COEFF_FRAC_BITS = COEFF_W - 1;
    
    always_comb begin
        // Y0 = P0 + z * (P4 - P1 - P2)
        acc_y0 = acc_p0 + (acc_p4_d - acc_p1_d - acc_p2_d);
        
        // Y1 = P3 - P0 - P1 + z * P2
        acc_y1 = acc_p3 - acc_p0 - acc_p1 + acc_p2_d;
        
        // Y2 = P5 - P0 - P2 + P1
        acc_y2 = acc_p5 - acc_p0 - acc_p2 + acc_p1;
    end
    
    // Output register
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
