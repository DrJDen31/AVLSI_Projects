import coeff_pkg::*;

module fir_pipe_fastfir_L3 #(
    parameter int PIPE_EVERY = 4 // Pipeline after this many taps in the subfilters
)(
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

    // This architecture combines pipeline registers with L=3 Fast FIR.
    // We break the 6 subfilters into pipelined MAC trees.
    
    localparam int MULT_W = DATA_W + COEFF_W + 1;
    localparam int L3_TAPS = (N_TAPS + 2) / 3;
    localparam int NUM_STAGES = (L3_TAPS + PIPE_EVERY - 1) / PIPE_EVERY;
    
    // Polyphase and pre-addition coefficients
    logic signed [COEFF_W-1:0] h0 [0:L3_TAPS-1];
    logic signed [COEFF_W-1:0] h1 [0:L3_TAPS-1];
    logic signed [COEFF_W-1:0] h2 [0:L3_TAPS-1];
    logic signed [COEFF_W:0]   h0_p_h1 [0:L3_TAPS-1];
    logic signed [COEFF_W:0]   h1_p_h2 [0:L3_TAPS-1];
    logic signed [COEFF_W:0]   h0_p_h2 [0:L3_TAPS-1];
    
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
    
    logic [NUM_STAGES:0] valid_sr;

    // Shift Registers and Valid Pipeline
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < L3_TAPS; i++) begin
                dl_x0[i] <= '0; dl_x1[i] <= '0; dl_x2[i] <= '0;
                dl_x0_p_x1[i] <= '0; dl_x1_p_x2[i] <= '0; dl_x0_p_x2[i] <= '0;
            end
            valid_sr[0] <= 1'b0;
        end else begin
            valid_sr[0] <= valid_in;
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

    // Multipliers (Combinational)
    logic signed [MULT_W-1:0] m_p0 [0:L3_TAPS-1];
    logic signed [MULT_W-1:0] m_p1 [0:L3_TAPS-1];
    logic signed [MULT_W-1:0] m_p2 [0:L3_TAPS-1];
    logic signed [DATA_W+COEFF_W+1:0] m_p3 [0:L3_TAPS-1]; // Note: DATA_W+COEFF_W+2 width
    logic signed [DATA_W+COEFF_W+1:0] m_p4 [0:L3_TAPS-1];
    logic signed [DATA_W+COEFF_W+1:0] m_p5 [0:L3_TAPS-1];
    
    always_comb begin
        for (int i = 0; i < L3_TAPS; i++) begin
            m_p0[i] = dl_x0[i] * h0[i];
            m_p1[i] = dl_x1[i] * h1[i];
            m_p2[i] = dl_x2[i] * h2[i];
            m_p3[i] = dl_x0_p_x1[i] * h0_p_h1[i];
            m_p4[i] = dl_x1_p_x2[i] * h1_p_h2[i];
            m_p5[i] = dl_x0_p_x2[i] * h0_p_h2[i];
        end
    end

    // Pipelined Subfilter Accumulators
    logic signed [ACC_W-1:0] acc_p0_pipe [0:NUM_STAGES];
    logic signed [ACC_W-1:0] acc_p1_pipe [0:NUM_STAGES];
    logic signed [ACC_W-1:0] acc_p2_pipe [0:NUM_STAGES];
    logic signed [ACC_W-1:0] acc_p3_pipe [0:NUM_STAGES];
    logic signed [ACC_W-1:0] acc_p4_pipe [0:NUM_STAGES];
    logic signed [ACC_W-1:0] acc_p5_pipe [0:NUM_STAGES];

    // Hoisted chunk sums (module scope for Quartus compatibility)
    logic signed [ACC_W-1:0] c_p0 [0:NUM_STAGES-1];
    logic signed [ACC_W-1:0] c_p1 [0:NUM_STAGES-1];
    logic signed [ACC_W-1:0] c_p2 [0:NUM_STAGES-1];
    logic signed [ACC_W-1:0] c_p3 [0:NUM_STAGES-1];
    logic signed [ACC_W-1:0] c_p4 [0:NUM_STAGES-1];
    logic signed [ACC_W-1:0] c_p5 [0:NUM_STAGES-1];

    // Compute chunk sums (Combinational)
    always_comb begin
        for (int s = 0; s < NUM_STAGES; s++) begin
            c_p0[s] = '0; c_p1[s] = '0; c_p2[s] = '0;
            c_p3[s] = '0; c_p4[s] = '0; c_p5[s] = '0;
            
            for (int j = 0; j < PIPE_EVERY; j++) begin
                if (s * PIPE_EVERY + j < L3_TAPS) begin
                    c_p0[s] = c_p0[s] + {{ (ACC_W - MULT_W){m_p0[s * PIPE_EVERY + j][MULT_W-1]} }, m_p0[s * PIPE_EVERY + j]};
                    c_p1[s] = c_p1[s] + {{ (ACC_W - MULT_W){m_p1[s * PIPE_EVERY + j][MULT_W-1]} }, m_p1[s * PIPE_EVERY + j]};
                    c_p2[s] = c_p2[s] + {{ (ACC_W - MULT_W){m_p2[s * PIPE_EVERY + j][MULT_W-1]} }, m_p2[s * PIPE_EVERY + j]};
                    
                    c_p3[s] = c_p3[s] + {{ (ACC_W - (DATA_W+COEFF_W+2)){m_p3[s * PIPE_EVERY + j][DATA_W+COEFF_W+1]} }, m_p3[s * PIPE_EVERY + j]};
                    c_p4[s] = c_p4[s] + {{ (ACC_W - (DATA_W+COEFF_W+2)){m_p4[s * PIPE_EVERY + j][DATA_W+COEFF_W+1]} }, m_p4[s * PIPE_EVERY + j]};
                    c_p5[s] = c_p5[s] + {{ (ACC_W - (DATA_W+COEFF_W+2)){m_p5[s * PIPE_EVERY + j][DATA_W+COEFF_W+1]} }, m_p5[s * PIPE_EVERY + j]};
                end
            end
        end
    end
    
    // Pipelined accumulation (Sequential)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int s = 0; s <= NUM_STAGES; s++) begin
                acc_p0_pipe[s] <= '0; acc_p1_pipe[s] <= '0; acc_p2_pipe[s] <= '0;
                acc_p3_pipe[s] <= '0; acc_p4_pipe[s] <= '0; acc_p5_pipe[s] <= '0;
                if (s > 0) valid_sr[s] <= 1'b0;
            end
        end else begin
            acc_p0_pipe[0] <= '0; acc_p1_pipe[0] <= '0; acc_p2_pipe[0] <= '0;
            acc_p3_pipe[0] <= '0; acc_p4_pipe[0] <= '0; acc_p5_pipe[0] <= '0;
            
            for (int s = 0; s < NUM_STAGES; s++) begin
                valid_sr[s+1] <= valid_sr[s];
                
                if (valid_sr[s]) begin
                    acc_p0_pipe[s+1] <= acc_p0_pipe[s] + c_p0[s];
                    acc_p1_pipe[s+1] <= acc_p1_pipe[s] + c_p1[s];
                    acc_p2_pipe[s+1] <= acc_p2_pipe[s] + c_p2[s];
                    acc_p3_pipe[s+1] <= acc_p3_pipe[s] + c_p3[s];
                    acc_p4_pipe[s+1] <= acc_p4_pipe[s] + c_p4[s];
                    acc_p5_pipe[s+1] <= acc_p5_pipe[s] + c_p5[s];
                end
            end
        end
    end

    // Sequential update for z^-1 delayed terms (applies after fully accumulated)
    // Delay matches valid_sr
    logic signed [ACC_W-1:0] acc_p1_d, acc_p2_d, acc_p4_d;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_p1_d <= '0; acc_p2_d <= '0; acc_p4_d <= '0;
        end else if (valid_sr[NUM_STAGES]) begin
            acc_p1_d <= acc_p1_pipe[NUM_STAGES];
            acc_p2_d <= acc_p2_pipe[NUM_STAGES];
            acc_p4_d <= acc_p4_pipe[NUM_STAGES];
        end
    end

    // Post-addition network
    logic signed [ACC_W-1:0] acc_y0, acc_y1, acc_y2;
    localparam int COEFF_FRAC_BITS = COEFF_W - 1;
    
    always_comb begin
        acc_y0 = acc_p0_pipe[NUM_STAGES] + (acc_p4_d - acc_p1_d - acc_p2_d);
        acc_y1 = acc_p3_pipe[NUM_STAGES] - acc_p0_pipe[NUM_STAGES] - acc_p1_pipe[NUM_STAGES] + acc_p2_d;
        acc_y2 = acc_p5_pipe[NUM_STAGES] - acc_p0_pipe[NUM_STAGES] - acc_p2_pipe[NUM_STAGES] + acc_p1_pipe[NUM_STAGES];
    end
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out_0 <= '0; data_out_1 <= '0; data_out_2 <= '0;
            valid_out  <= 1'b0;
        end else begin
            // Valid out is delayed by one more cycle to match the output registers
            valid_out <= valid_sr[NUM_STAGES];
            if (valid_sr[NUM_STAGES]) begin
                data_out_0 <= acc_y0[COEFF_FRAC_BITS +: DATA_W];
                data_out_1 <= acc_y1[COEFF_FRAC_BITS +: DATA_W];
                data_out_2 <= acc_y2[COEFF_FRAC_BITS +: DATA_W];
            end
        end
    end

endmodule
