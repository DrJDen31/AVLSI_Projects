import coeff_pkg::*;

module fir_tb_L3;
    timeunit 1ns;
    
    localparam int CLK_PERIOD = 10;
    localparam int NUM_SAMPLES = 3750;

    logic clk, rst_n, valid_in, valid_out;
    logic signed [DATA_W-1:0] data_in0, data_in1, data_in2;
    logic signed [DATA_W-1:0] data_out0, data_out1, data_out2;
    logic signed [DATA_W-1:0] stimulus_mem [0:NUM_SAMPLES-1];
    logic signed [ACC_W-1:0]  golden_mem    [0:NUM_SAMPLES-1];

    // -- Reconstruction Helpers for Waveforms --
    logic signed [DATA_W-1:0] data_in_recon;
    logic signed [DATA_W-1:0] data_out_recon;
    
    initial begin
        $readmemh("tb/test_vectors/input_stimulus.hex", stimulus_mem);
        $readmemh("tb/test_vectors/golden_output.hex", golden_mem);
    end

    initial begin clk = 0; forever #(CLK_PERIOD/2) clk = ~clk; end

    // Change to fir_parallel_L3, fir_fastfir_L3, or fir_pipe_fastfir_L3
    // fir_parallel_L3 dut (
    //     .clk(clk), .rst_n(rst_n),
    //     .valid_in(valid_in), .data_in_0(data_in0), .data_in_1(data_in1), .data_in_2(data_in2),
    //     .valid_out(valid_out), .data_out_0(data_out0), .data_out_1(data_out1), .data_out_2(data_out2)
    // );
    fir_pipe_fastfir_L3 dut (
        .clk(clk), .rst_n(rst_n),
        .valid_in(valid_in), .data_in_0(data_in0), .data_in_1(data_in1), .data_in_2(data_in2),
        .valid_out(valid_out), .data_out_0(data_out0), .data_out_1(data_out1), .data_out_2(data_out2)
    );

    int sample_idx = 0;
    initial begin
        valid_in = 0; data_in0 = '0; data_in1 = '0; data_in2 = '0; rst_n = 0;
        #(CLK_PERIOD * 10); rst_n = 1; #(CLK_PERIOD * 2);
        
        for (int i = 0; i < NUM_SAMPLES/3; i++) begin
            @(posedge clk);
            valid_in  <= 1'b1;
            data_in0  <= stimulus_mem[3*i];
            data_in1  <= stimulus_mem[3*i+1];
            data_in2  <= stimulus_mem[3*i+2];
        end
        @(posedge clk); valid_in <= 1'b0;
        #(CLK_PERIOD * 100); $finish;
    end

    always_ff @(posedge clk) begin
        if (valid_out) begin
            logic signed [DATA_W-1:0] exp0, exp1, exp2;
            exp0 = golden_mem[sample_idx][(COEFF_W-1) +: DATA_W];
            exp1 = golden_mem[sample_idx+1][(COEFF_W-1) +: DATA_W];
            exp2 = golden_mem[sample_idx+2][(COEFF_W-1) +: DATA_W];
            if (data_out0 !== exp0 && data_out0 !== exp0+1 && data_out0 !== exp0-1)
                $display("ERR L3 [%0d]: Got %d, Exp %d", sample_idx, data_out0, exp0);
            if (data_out1 !== exp1 && data_out1 !== exp1+1 && data_out1 !== exp1-1)
                $display("ERR L3 [%0d]: Got %d, Exp %d", sample_idx+1, data_out1, exp1);
            if (data_out2 !== exp2 && data_out2 !== exp2+1 && data_out2 !== exp2-1)
                $display("ERR L3 [%0d]: Got %d, Exp %d", sample_idx+2, data_out2, exp2);
            sample_idx += 3;
        end
    end

    // Clock-internal interleaving for analog reconstruction
    always @(posedge clk) begin
        #1;
        if (valid_in) begin
            data_in_recon <= data_in0;
            #(CLK_PERIOD/3.0) data_in_recon <= data_in1;
            #(CLK_PERIOD/3.0) data_in_recon <= data_in2;
        end else begin
            data_in_recon <= '0;
        end
    end

    always @(posedge clk) begin
        #1;
        if (valid_out) begin
            data_out_recon <= data_out0;
            #(CLK_PERIOD/3.0) data_out_recon <= data_out1;
            #(CLK_PERIOD/3.0) data_out_recon <= data_out2;
        end else begin
            data_out_recon <= '0;
        end
    end
endmodule
