import coeff_pkg::*;

module fir_tb_L1;
    timeunit 1ns;

    localparam int CLK_PERIOD = 10;
    localparam int NUM_SAMPLES = 3750;

    logic clk, rst_n, valid_in, valid_out;
    logic signed [DATA_W-1:0] data_in, data_out;
    logic signed [DATA_W-1:0] stimulus_mem [0:NUM_SAMPLES-1];
    logic signed [ACC_W-1:0]  golden_mem    [0:NUM_SAMPLES-1];
    
    initial begin
        $readmemh("tb/test_vectors/input_stimulus.hex", stimulus_mem);
        $readmemh("tb/test_vectors/golden_output.hex", golden_mem);
    end

    initial begin clk = 0; forever #(CLK_PERIOD/2) clk = ~clk; end

    // Change this instantiation to test fir_direct or fir_pipelined
    // fir_direct dut (
    //     .clk(clk), .rst_n(rst_n),
    //     .valid_in(valid_in), .data_in(data_in),
    //     .valid_out(valid_out), .data_out(data_out)
    // );
    fir_pipelined dut (
        .clk(clk), .rst_n(rst_n),
        .valid_in(valid_in), .data_in(data_in),
        .valid_out(valid_out), .data_out(data_out)
    );

    int sample_idx = 0;
    initial begin
        valid_in = 0; data_in = '0; rst_n = 0;
        #(CLK_PERIOD * 10); rst_n = 1; #(CLK_PERIOD * 2);
        
        for (int i = 0; i < NUM_SAMPLES; i++) begin
            @(posedge clk);
            valid_in <= 1'b1;
            data_in  <= stimulus_mem[i];
        end
        @(posedge clk); valid_in <= 1'b0;
        #(CLK_PERIOD * 100); $finish;
    end

    always_ff @(posedge clk) begin
        if (valid_out) begin
            logic signed [DATA_W-1:0] expected;
            expected = golden_mem[sample_idx][(COEFF_W-1) +: DATA_W];
            if (data_out !== expected && data_out !== expected+1 && data_out !== expected-1)
                $display("ERR L1 [%0d]: Got %d, Exp %d", sample_idx, data_out, expected);
            sample_idx++;
        end
    end
endmodule
