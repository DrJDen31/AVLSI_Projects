import coeff_pkg::*;

module fir_pipelined #(
    parameter int PIPE_EVERY = 4
)(
    input  logic                 clk,
    input  logic                 rst_n,
    
    input  logic                 valid_in,
    input  logic signed [DATA_W-1:0] data_in,
    
    output logic                 valid_out,
    output logic signed [DATA_W-1:0] data_out
);

    localparam int MULT_W = DATA_W + COEFF_W;
    
    // Pipelined Adder Tree Stage Sizes (Supports up to PIPE_EVERY^4 taps)
    localparam int S1_N = (N_TAPS + PIPE_EVERY - 1) / PIPE_EVERY;
    localparam int S2_N = (S1_N > 1) ? (S1_N + PIPE_EVERY - 1) / PIPE_EVERY : 1;
    localparam int S3_N = (S2_N > 1) ? (S2_N + PIPE_EVERY - 1) / PIPE_EVERY : 1;
    localparam int S4_N = 1;

    logic signed [DATA_W-1:0] delay_line [0:N_TAPS-1];
    logic signed [MULT_W-1:0] mult_out [0:N_TAPS-1];
    
    logic signed [ACC_W-1:0] stg1 [0:S1_N-1];
    logic signed [ACC_W-1:0] stg2 [0:S2_N-1];
    logic signed [ACC_W-1:0] stg3 [0:S3_N-1];
    logic signed [ACC_W-1:0] stg4 [0:S4_N-1];
    
    logic valid_d, valid_s1, valid_s2, valid_s3, valid_s4;

    // Delay line requires 1 cycle, so valid must be delayed to match
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) valid_d <= 1'b0;
        else valid_d <= valid_in;
    end

    // Shift Register (Delay Line) + Multipliers
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < N_TAPS; i++) delay_line[i] <= '0;
        end else if (valid_in) begin
            delay_line[0] <= data_in;
            for (int i = 1; i < N_TAPS; i++) delay_line[i] <= delay_line[i-1];
        end
    end
    
    always_comb begin
        for (int i = 0; i < N_TAPS; i++) mult_out[i] = delay_line[i] * COEFFS[i];
    end

    // Pipelined Adder Tree
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_s1 <= 0; valid_s2 <= 0; valid_s3 <= 0; valid_s4 <= 0;
            for(int i=0; i<S1_N; i++) stg1[i] <= '0;
            for(int i=0; i<S2_N; i++) stg2[i] <= '0;
            for(int i=0; i<S3_N; i++) stg3[i] <= '0;
            stg4[0] <= '0;
        end else begin
            valid_s1 <= valid_d;
            valid_s2 <= valid_s1;
            valid_s3 <= valid_s2;
            valid_s4 <= valid_s3;

            // Stage 1
            if (valid_d) begin
                for (int i = 0; i < S1_N; i++) begin
                    logic signed [ACC_W-1:0] temp;
                    temp = '0;
                    for (int j = 0; j < PIPE_EVERY; j++) begin
                        if (i*PIPE_EVERY + j < N_TAPS)
                            temp += {{ (ACC_W - MULT_W){mult_out[i*PIPE_EVERY + j][MULT_W-1]} }, mult_out[i*PIPE_EVERY + j]};
                    end
                    stg1[i] <= temp;
                end
            end

            // Stage 2
            if (valid_s1) begin
                for (int i = 0; i < S2_N; i++) begin
                    logic signed [ACC_W-1:0] temp;
                    temp = '0;
                    for (int j = 0; j < PIPE_EVERY; j++) begin
                        if (i*PIPE_EVERY + j < S1_N)
                            temp += stg1[i*PIPE_EVERY + j];
                    end
                    stg2[i] <= temp;
                end
            end

            // Stage 3
            if (valid_s2) begin
                for (int i = 0; i < S3_N; i++) begin
                    logic signed [ACC_W-1:0] temp;
                    temp = '0;
                    for (int j = 0; j < PIPE_EVERY; j++) begin
                        if (i*PIPE_EVERY + j < S2_N)
                            temp += stg2[i*PIPE_EVERY + j];
                    end
                    stg3[i] <= temp;
                end
            end

            // Stage 4 (Final Accumulation)
            if (valid_s3) begin
                logic signed [ACC_W-1:0] temp;
                temp = '0;
                for (int j = 0; j < PIPE_EVERY; j++) begin
                    if (j < S3_N) temp += stg3[j];
                end
                stg4[0] <= temp;
            end
        end
    end

    // Output Stage
    localparam int COEFF_FRAC_BITS = COEFF_W - 1;
    always_comb begin
        valid_out = valid_s4;
        data_out  = stg4[0][COEFF_FRAC_BITS +: DATA_W];
    end
endmodule
