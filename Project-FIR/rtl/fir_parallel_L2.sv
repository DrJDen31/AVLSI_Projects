import coeff_pkg::*;

module fir_parallel_L2 (
    input  logic                 clk,
    input  logic                 rst_n,
    
    input  logic                 valid_in,
    // Accepts 2 samples per clock cycle
    input  logic signed [DATA_W-1:0] data_in_0, // x[2k]
    input  logic signed [DATA_W-1:0] data_in_1, // x[2k+1]
    
    output logic                 valid_out,
    // Outputs 2 samples per clock cycle
    output logic signed [DATA_W-1:0] data_out_0, // y[2k]
    output logic signed [DATA_W-1:0] data_out_1  // y[2k+1]
);

    // Simple L=2 Polyphase Decomposition
    // H(z) = H0(z^2) + z^-1 H1(z^2)
    // where H0 = even taps, H1 = odd taps
    
    // y0 = H0*x0 + z^-1(H1)*x1
    // y1 = H0*x1 + H1*x0
    
    localparam int MULT_W = DATA_W + COEFF_W;
    localparam int L2_TAPS = (N_TAPS + 1) / 2; // Ceil division
    
    // Polyphase coefficients
    logic signed [COEFF_W-1:0] h0 [0:L2_TAPS-1];
    logic signed [COEFF_W-1:0] h1 [0:L2_TAPS-1];
    
    initial begin
        for(int i=0; i<N_TAPS; i++) begin
            if (i % 2 == 0) h0[i/2] = COEFFS[i];
            else            h1[i/2] = COEFFS[i];
        end
        // If N_TAPS is odd, the last h1 is 0
        if (N_TAPS % 2 != 0) h1[L2_TAPS-1] = '0;
    end
    
    // Delay lines for subfilters
    // Each operates at Fs/2
    logic signed [DATA_W-1:0] dl_x0 [0:L2_TAPS-1];
    logic signed [DATA_W-1:0] dl_x1 [0:L2_TAPS-1];
    
    // Previous x1 for the z^-1 term in y0 equation
    logic signed [DATA_W-1:0] dl_x1_delayed [0:L2_TAPS-1];
    
    logic valid_p1;

    // Shift Registers
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < L2_TAPS; i++) begin
                dl_x0[i] <= '0;
                dl_x1[i] <= '0;
                dl_x1_delayed[i] <= '0;
            end
            valid_p1 <= 1'b0;
        end else begin
            valid_p1 <= valid_in;
            if (valid_in) begin
                dl_x0[0] <= data_in_0;
                dl_x1[0] <= data_in_1;
                dl_x1_delayed[0] <= dl_x1[0]; // z^-1 delay for x1
                
                for (int i = 1; i < L2_TAPS; i++) begin
                    dl_x0[i] <= dl_x0[i-1];
                    dl_x1[i] <= dl_x1[i-1];
                    dl_x1_delayed[i] <= dl_x1_delayed[i-1];
                end
            end
        end
    end

    // Hoisted multiplier results (declared at module scope for Quartus compatibility)
    logic signed [MULT_W-1:0] m_h0_x0 [0:L2_TAPS-1];
    logic signed [MULT_W-1:0] m_h1_x1_d [0:L2_TAPS-1];
    logic signed [MULT_W-1:0] m_h0_x1 [0:L2_TAPS-1];
    logic signed [MULT_W-1:0] m_h1_x0 [0:L2_TAPS-1];

    // Combinational MAC for y0 and y1
    logic signed [ACC_W-1:0] acc_y0;
    logic signed [ACC_W-1:0] acc_y1;
    
    always_comb begin
        acc_y0 = '0;
        acc_y1 = '0;
        
        for (int i = 0; i < L2_TAPS; i++) begin
            // Multiplications
            m_h0_x0[i] = dl_x0[i] * h0[i];
            m_h1_x1_d[i] = dl_x1_delayed[i] * h1[i];
            m_h0_x1[i] = dl_x1[i] * h0[i];
            m_h1_x0[i] = dl_x0[i] * h1[i];
            
            // Accumulate y0 = H0*x0 + z^-1(H1)*x1
            acc_y0 = acc_y0 + {{ (ACC_W - MULT_W){m_h0_x0[i][MULT_W-1]} }, m_h0_x0[i]} 
                            + {{ (ACC_W - MULT_W){m_h1_x1_d[i][MULT_W-1]} }, m_h1_x1_d[i]};
                            
            // Accumulate y1 = H0*x1 + H1*x0
            acc_y1 = acc_y1 + {{ (ACC_W - MULT_W){m_h0_x1[i][MULT_W-1]} }, m_h0_x1[i]} 
                            + {{ (ACC_W - MULT_W){m_h1_x0[i][MULT_W-1]} }, m_h1_x0[i]};
        end
    end

    // Output Stage
    localparam int COEFF_FRAC_BITS = COEFF_W - 1;
    
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
