import coeff_pkg::*;

module fir_pipelined #(
    // Pipeline granularity: Insert a register every M taps.
    // If M=1, fully pipelined (reg after every multiply).
    // If M=4, pipeline every 4th adder.
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
    localparam int NUM_STAGES = (N_TAPS + PIPE_EVERY - 1) / PIPE_EVERY;
    
    // Delay line for input samples
    logic signed [DATA_W-1:0] delay_line [0:N_TAPS-1];
    
    // Valid signal shift register (matches algorithmic latency)
    // Latency = 1 (delay line) + NUM_STAGES (pipeline array)
    logic [NUM_STAGES:0] valid_sr;
    
    // Multipliers (Combinational)
    logic signed [MULT_W-1:0] mult_out [0:N_TAPS-1];
    
    // Pipelined Accumulator Array
    // We break the N_TAPS additions into NUM_STAGES chunks.
    logic signed [ACC_W-1:0] acc_pipe [0:NUM_STAGES];

    // Pre-declared chunk sum for pipeline stages (hoisted out of always_ff)
    logic signed [ACC_W-1:0] chunk_sum [0:NUM_STAGES-1];

    // 1. Shift Register (Delay Line)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < N_TAPS; i++) begin
                delay_line[i] <= '0;
            end
            valid_sr[0] <= 1'b0;
        end else begin
            valid_sr[0] <= valid_in;
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

    // 3. Compute chunk sums (Combinational)
    always_comb begin
        for (int s = 0; s < NUM_STAGES; s++) begin
            chunk_sum[s] = '0;
            for (int j = 0; j < PIPE_EVERY; j++) begin
                if (s * PIPE_EVERY + j < N_TAPS) begin
                    chunk_sum[s] = chunk_sum[s] + {{ (ACC_W - MULT_W){mult_out[s * PIPE_EVERY + j][MULT_W-1]} }, mult_out[s * PIPE_EVERY + j]};
                end
            end
        end
    end

    // 4. Pipelined Accumulator (Sequential)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int s = 0; s <= NUM_STAGES; s++) begin
                acc_pipe[s] <= '0;
                if (s > 0) valid_sr[s] <= 1'b0;
            end
        end else begin
            acc_pipe[0] <= '0;
            
            for (int s = 0; s < NUM_STAGES; s++) begin
                valid_sr[s+1] <= valid_sr[s];
                
                if (valid_sr[s]) begin
                    acc_pipe[s+1] <= acc_pipe[s] + chunk_sum[s];
                end
            end
        end
    end

    // 5. Output Stage
    localparam int COEFF_FRAC_BITS = COEFF_W - 1;
    
    always_comb begin
        valid_out = valid_sr[NUM_STAGES];
        data_out  = acc_pipe[NUM_STAGES][COEFF_FRAC_BITS +: DATA_W];
    end

endmodule
