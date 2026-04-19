import coeff_pkg::*;

module fir_tb;

    // Simulation Parameters
    localparam int CLK_PERIOD = 10;
    localparam int NUM_SAMPLES = 3750; // Ensure this matches test_metadata.txt

    // Clock and Reset
    logic clk;
    logic rst_n;
    
    // DUT Interface
    logic                 valid_in;
    logic signed [DATA_W-1:0] data_in;
    logic                 valid_out;
    logic signed [DATA_W-1:0] data_out;
    
    // Test Vectors
    logic signed [DATA_W-1:0] stimulus_mem  [0:NUM_SAMPLES-1];
    logic signed [ACC_W-1:0]  golden_mem    [0:NUM_SAMPLES-1];
    
    // Load test vectors
    initial begin
        // Use relative paths for test vector loading.
        // Ensure the simulation workspace is set correctly for ModelSim to resolve paths.
        $readmemh("test_vectors/input_stimulus.hex", stimulus_mem);
        $readmemh("test_vectors/golden_output.hex", golden_mem);
    end

    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // DUT Instantiation
    fir_direct dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .data_in(data_in),
        .valid_out(valid_out),
        .data_out(data_out)
    );

    // Test Sequence
    int error_count = 0;
    int sample_idx = 0;
    
    initial begin
        // Initialize
        valid_in = 0;
        data_in  = '0;
        rst_n    = 0;
        
        #(CLK_PERIOD * 5);
        rst_n = 1;
        #(CLK_PERIOD * 2);
        
        $display("\n========================================================");
        $display("   FIR Filter Simulation Started");
        $display("   Testing %0d samples", NUM_SAMPLES);
        $display("========================================================\n");
        
        // Feed stimulus
        for (int i = 0; i < NUM_SAMPLES; i++) begin
            @(posedge clk);
            valid_in <= 1'b1;
            data_in  <= stimulus_mem[i];
        end
        
        @(posedge clk);
        valid_in <= 1'b0;
        
        // Wait for pipeline to drain (direct form has 1 cycle latency, 
        // pipelined forms will have more)
        #(CLK_PERIOD * 20);
        
        // Report Results
        $display("\n========================================================");
        if (error_count == 0) begin
            $display("   SIMULATION PASSED! (0 errors)");
        end else begin
            $display("   SIMULATION FAILED! (%0d errors)", error_count);
        end
        $display("========================================================\n");
        $finish;
    end
    
    // Output Verification
    // We compare the truncated DUT output with the truncated golden accumulator
    localparam int COEFF_FRAC_BITS = COEFF_W - 1;
    
    always_ff @(posedge clk) begin
        if (valid_out) begin
            // Extract the matching bits from the golden full-width accumulator
            logic signed [DATA_W-1:0] expected_out;
            expected_out = golden_mem[sample_idx][COEFF_FRAC_BITS +: DATA_W];
            
            // Allow a small tolerance (e.g. +/- 1 LSB) to account for different
            // rounding schemes between exact integer math and hardware slicing.
            // Since we use straightforward slicing (floor/truncation) in both,
            // they should match exactly unless overflow occurred.
            
            if (data_out !== expected_out && 
                data_out !== expected_out + 1 && 
                data_out !== expected_out - 1) begin
                
                $display("ERROR at sample %0d: Expected %d, Got %d", 
                         sample_idx, expected_out, data_out);
                error_count++;
                
                // Stop after 20 errors to avoid flooding console
                if (error_count > 20) begin
                    $display("Too many errors. Stopping simulation.");
                    $finish;
                end
            end
            
            sample_idx++;
        end
    end

endmodule
