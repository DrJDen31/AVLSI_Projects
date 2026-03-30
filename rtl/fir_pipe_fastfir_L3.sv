import coeff_pkg::*;

module fir_pipe_fastfir_L3 #(
    parameter int PIPE_EVERY = 4
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

    localparam int L3_TAPS = (N_TAPS + 2) / 3;
    localparam int MULT_W = DATA_W + COEFF_W + 1;
    localparam int MULT_W_P = DATA_W + COEFF_W + 2;
    
    // Pipelined Adder Tree Stage Sizes (Supports up to PIPE_EVERY^4 parallel taps)
    localparam int S1_N = (L3_TAPS + PIPE_EVERY - 1) / PIPE_EVERY;
    localparam int S2_N = (S1_N > 1) ? (S1_N + PIPE_EVERY - 1) / PIPE_EVERY : 1;
    localparam int S3_N = (S2_N > 1) ? (S2_N + PIPE_EVERY - 1) / PIPE_EVERY : 1;
    localparam int S4_N = 1;

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

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < L3_TAPS; i++) begin
                dl_x0[i] <= '0; dl_x1[i] <= '0; dl_x2[i] <= '0;
                dl_x0_p_x1[i] <= '0; dl_x1_p_x2[i] <= '0; dl_x0_p_x2[i] <= '0;
            end
        end else begin
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

    // Combinational Multipliers
    logic signed [MULT_W-1:0] m_p0 [0:L3_TAPS-1];
    logic signed [MULT_W-1:0] m_p1 [0:L3_TAPS-1];
    logic signed [MULT_W-1:0] m_p2 [0:L3_TAPS-1];
    logic signed [MULT_W_P-1:0] m_p3 [0:L3_TAPS-1];
    logic signed [MULT_W_P-1:0] m_p4 [0:L3_TAPS-1];
    logic signed [MULT_W_P-1:0] m_p5 [0:L3_TAPS-1];
    
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

    // Pipelined Adder Tree Arrays
    logic signed [ACC_W-1:0] p0_s1 [0:S1_N-1], p1_s1 [0:S1_N-1], p2_s1 [0:S1_N-1], p3_s1 [0:S1_N-1], p4_s1 [0:S1_N-1], p5_s1 [0:S1_N-1];
    logic signed [ACC_W-1:0] p0_s2 [0:S2_N-1], p1_s2 [0:S2_N-1], p2_s2 [0:S2_N-1], p3_s2 [0:S2_N-1], p4_s2 [0:S2_N-1], p5_s2 [0:S2_N-1];
    logic signed [ACC_W-1:0] p0_s3 [0:S3_N-1], p1_s3 [0:S3_N-1], p2_s3 [0:S3_N-1], p3_s3 [0:S3_N-1], p4_s3 [0:S3_N-1], p5_s3 [0:S3_N-1];
    logic signed [ACC_W-1:0] p0_s4 [0:S4_N-1], p1_s4 [0:S4_N-1], p2_s4 [0:S4_N-1], p3_s4 [0:S4_N-1], p4_s4 [0:S4_N-1], p5_s4 [0:S4_N-1];
    
    logic valid_d, valid_s1, valid_s2, valid_s3, valid_s4;

    // Shift registers for valid line matches the 1-cycle latency of the initial split delay lines
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) valid_d <= 1'b0;
        else valid_d <= valid_in;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_s1 <= 0; valid_s2 <= 0; valid_s3 <= 0; valid_s4 <= 0;
            for(int i=0; i<S1_N; i++) begin
                p0_s1[i]<='0; p1_s1[i]<='0; p2_s1[i]<='0; p3_s1[i]<='0; p4_s1[i]<='0; p5_s1[i]<='0;
            end
            for(int i=0; i<S2_N; i++) begin
                p0_s2[i]<='0; p1_s2[i]<='0; p2_s2[i]<='0; p3_s2[i]<='0; p4_s2[i]<='0; p5_s2[i]<='0;
            end
            for(int i=0; i<S3_N; i++) begin
                p0_s3[i]<='0; p1_s3[i]<='0; p2_s3[i]<='0; p3_s3[i]<='0; p4_s3[i]<='0; p5_s3[i]<='0;
            end
            for(int i=0; i<S4_N; i++) begin
                p0_s4[i]<='0; p1_s4[i]<='0; p2_s4[i]<='0; p3_s4[i]<='0; p4_s4[i]<='0; p5_s4[i]<='0;
            end
        end else begin
            valid_s1 <= valid_d;
            valid_s2 <= valid_s1;
            valid_s3 <= valid_s2;
            valid_s4 <= valid_s3;

            // Stage 1
            if (valid_d) begin
                for (int i = 0; i < S1_N; i++) begin
                    logic signed [ACC_W-1:0] t0, t1, t2, t3, t4, t5;
                    t0='0; t1='0; t2='0; t3='0; t4='0; t5='0;
                    for (int j = 0; j < PIPE_EVERY; j++) begin
                        if (i*PIPE_EVERY + j < L3_TAPS) begin
                            t0 += {{ (ACC_W - MULT_W){m_p0[i*PIPE_EVERY+j][MULT_W-1]} }, m_p0[i*PIPE_EVERY+j]};
                            t1 += {{ (ACC_W - MULT_W){m_p1[i*PIPE_EVERY+j][MULT_W-1]} }, m_p1[i*PIPE_EVERY+j]};
                            t2 += {{ (ACC_W - MULT_W){m_p2[i*PIPE_EVERY+j][MULT_W-1]} }, m_p2[i*PIPE_EVERY+j]};
                            t3 += {{ (ACC_W - MULT_W_P){m_p3[i*PIPE_EVERY+j][MULT_W_P-1]} }, m_p3[i*PIPE_EVERY+j]};
                            t4 += {{ (ACC_W - MULT_W_P){m_p4[i*PIPE_EVERY+j][MULT_W_P-1]} }, m_p4[i*PIPE_EVERY+j]};
                            t5 += {{ (ACC_W - MULT_W_P){m_p5[i*PIPE_EVERY+j][MULT_W_P-1]} }, m_p5[i*PIPE_EVERY+j]};
                        end
                    end
                    p0_s1[i] <= t0; p1_s1[i] <= t1; p2_s1[i] <= t2;
                    p3_s1[i] <= t3; p4_s1[i] <= t4; p5_s1[i] <= t5;
                end
            end

            // Stage 2
            if (valid_s1) begin
                for (int i = 0; i < S2_N; i++) begin
                    logic signed [ACC_W-1:0] t0, t1, t2, t3, t4, t5;
                    t0='0; t1='0; t2='0; t3='0; t4='0; t5='0;
                    for (int j = 0; j < PIPE_EVERY; j++) begin
                        if (i*PIPE_EVERY + j < S1_N) begin
                            t0 += p0_s1[i*PIPE_EVERY+j]; t1 += p1_s1[i*PIPE_EVERY+j]; t2 += p2_s1[i*PIPE_EVERY+j];
                            t3 += p3_s1[i*PIPE_EVERY+j]; t4 += p4_s1[i*PIPE_EVERY+j]; t5 += p5_s1[i*PIPE_EVERY+j];
                        end
                    end
                    p0_s2[i] <= t0; p1_s2[i] <= t1; p2_s2[i] <= t2;
                    p3_s2[i] <= t3; p4_s2[i] <= t4; p5_s2[i] <= t5;
                end
            end

            // Stage 3
            if (valid_s2) begin
                for (int i = 0; i < S3_N; i++) begin
                    logic signed [ACC_W-1:0] t0, t1, t2, t3, t4, t5;
                    t0='0; t1='0; t2='0; t3='0; t4='0; t5='0;
                    for (int j = 0; j < PIPE_EVERY; j++) begin
                        if (i*PIPE_EVERY + j < S2_N) begin
                            t0 += p0_s2[i*PIPE_EVERY+j]; t1 += p1_s2[i*PIPE_EVERY+j]; t2 += p2_s2[i*PIPE_EVERY+j];
                            t3 += p3_s2[i*PIPE_EVERY+j]; t4 += p4_s2[i*PIPE_EVERY+j]; t5 += p5_s2[i*PIPE_EVERY+j];
                        end
                    end
                    p0_s3[i] <= t0; p1_s3[i] <= t1; p2_s3[i] <= t2;
                    p3_s3[i] <= t3; p4_s3[i] <= t4; p5_s3[i] <= t5;
                end
            end

            // Stage 4 (Final Accumulation)
            if (valid_s3) begin
                for (int i = 0; i < S4_N; i++) begin
                    logic signed [ACC_W-1:0] t0, t1, t2, t3, t4, t5;
                    t0='0; t1='0; t2='0; t3='0; t4='0; t5='0;
                    for (int j = 0; j < PIPE_EVERY; j++) begin
                        if (i*PIPE_EVERY + j < S3_N) begin
                            t0 += p0_s3[i*PIPE_EVERY+j]; t1 += p1_s3[i*PIPE_EVERY+j]; t2 += p2_s3[i*PIPE_EVERY+j];
                            t3 += p3_s3[i*PIPE_EVERY+j]; t4 += p4_s3[i*PIPE_EVERY+j]; t5 += p5_s3[i*PIPE_EVERY+j];
                        end
                    end
                    p0_s4[i] <= t0; p1_s4[i] <= t1; p2_s4[i] <= t2;
                    p3_s4[i] <= t3; p4_s4[i] <= t4; p5_s4[i] <= t5;
                end
            end
        end
    end

    // Post-addition network delayed variables
    logic signed [ACC_W-1:0] acc_p1_d, acc_p2_d, acc_p4_d;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_p1_d <= '0; acc_p2_d <= '0; acc_p4_d <= '0;
        end else if (valid_s4) begin
            acc_p1_d <= p1_s4[0];
            acc_p2_d <= p2_s4[0];
            acc_p4_d <= p4_s4[0];
        end
    end

    // Combinational addition
    logic signed [ACC_W-1:0] acc_y0, acc_y1, acc_y2;
    localparam int COEFF_FRAC_BITS = COEFF_W - 1;
    always_comb begin
        acc_y0 = p0_s4[0] + (acc_p4_d - acc_p1_d - acc_p2_d);
        acc_y1 = p3_s4[0] - p0_s4[0] - p1_s4[0] + acc_p2_d;
        acc_y2 = p5_s4[0] - p0_s4[0] - p2_s4[0] + p1_s4[0];
    end
    
    // Output Registers
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out_0 <= '0; data_out_1 <= '0; data_out_2 <= '0;
            valid_out  <= 1'b0;
        end else begin
            valid_out <= valid_s4;
            if (valid_s4) begin
                data_out_0 <= acc_y0[COEFF_FRAC_BITS +: DATA_W];
                data_out_1 <= acc_y1[COEFF_FRAC_BITS +: DATA_W];
                data_out_2 <= acc_y2[COEFF_FRAC_BITS +: DATA_W];
            end
        end
    end

endmodule
