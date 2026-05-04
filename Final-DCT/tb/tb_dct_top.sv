// tb_dct_top.sv - top-level testbench, drives test_vectors.hex, checks golden_coeffs_fixed.txt
// Loads pixel data from test_vectors.hex, drives the full 2D DCT pipeline,
// compares output coefficients against MATLAB-generated golden reference.
//
// NOTE: golden_coeffs_fixed.txt contains pre-quantization 2D DCT coefficients.
// This testbench instantiates the DCT pipeline WITHOUT quantization to match the golden.
// Quantization is verified separately in tb_quantizer.sv.
`timescale 1ns/1ps
module tb_dct_top;

    parameter int DATA_WIDTH      = 16;
    parameter int COEFF_WIDTH     = 16;
    parameter int ACCUM_WIDTH     = 32;
    parameter int FRAC_BITS       = 14;
    parameter int PARALLEL        = 0;
    parameter int PIPELINE_STAGES = 1;
    parameter int NUM_BLOCKS      = 4096;   // Number of 8x8 blocks in test vectors

    logic                          clk, rst_n;
    logic [7:0]                    pixel_in;
    logic                          pixel_valid;
    logic                          pixel_ready;
    logic signed [DATA_WIDTH-1:0]  coeff_out;
    logic                          coeff_valid;
    logic                          coeff_rd;
    logic                          block_ready;
    logic                          block_done;

    top_dct_accelerator #(
        .DATA_WIDTH      (DATA_WIDTH),
        .COEFF_WIDTH     (COEFF_WIDTH),
        .ACCUM_WIDTH     (ACCUM_WIDTH),
        .FRAC_BITS       (FRAC_BITS),
        .PARALLEL        (PARALLEL),
        .PIPELINE_STAGES (PIPELINE_STAGES),
        .SKIP_QUANTIZER  (1)              // Bypass quantizer for golden comparison
    ) dut (.*);

    always #5 clk = ~clk;

    // ---- Test data ----
    // Load pixel data from test_vectors.hex (1024 pixels = 16 blocks × 64 pixels)
    logic [7:0] pixel_mem [0:NUM_BLOCKS*64-1];
    initial begin
        $readmemh("test_vectors.hex", pixel_mem);
    end

    // Load golden coefficients from golden_coeffs_fixed.txt (16-bit signed hex)
    logic [15:0] golden_mem [0:NUM_BLOCKS*64-1];
    initial begin
        $readmemh("golden_coeffs_fixed.txt", golden_mem);
    end

    // ---- Drive pixels ----
    int pixel_idx;
    int block_num;
    int coeff_idx;       // Global coefficient index for golden comparison
    int block_coeff_idx; // Coefficient index within current block (0..63)
    int mismatches;
    int total_compared;

    int fd;
    string filename;

    initial begin
        if (!$value$plusargs("FILENAME=%s", filename)) begin
            filename = "sim_coeffs_default.txt";
        end
        fd = $fopen(filename, "w");
        if (fd == 0) $fatal(1, "Could not open output file %s", filename);

        clk = 0; rst_n = 0; pixel_valid = 0; pixel_in = '0; coeff_rd = 0;
        pixel_idx   = 0;
        block_num   = 0;
        coeff_idx   = 0;
        mismatches  = 0;
        total_compared = 0;

        repeat (5) @(posedge clk);
        #1; rst_n = 1;
        @(posedge clk); #1;

        // Process all blocks
        for (block_num = 0; block_num < NUM_BLOCKS; block_num++) begin
            $display("Processing block %0d / %0d ...", block_num, NUM_BLOCKS-1);

            // Feed 64 pixels for this block
            for (int i = 0; i < 64; i++) begin
                // Wait for pixel_ready
                while (!pixel_ready) @(posedge clk); #1;
                pixel_in    = pixel_mem[block_num * 64 + i];
                pixel_valid = 1;
                @(posedge clk); #1;
            end
            pixel_valid = 0;

            // Wait for block_ready (output available)
            while (!block_ready) begin
                @(posedge clk); #1;
            end

            // Read 64 output coefficients and compare
            block_coeff_idx = 0;
            while (block_coeff_idx < 64) begin
                coeff_rd = 1;
                @(posedge clk); #1;
                if (coeff_valid) begin
                    begin
                        automatic int golden_idx = block_num * 64 + block_coeff_idx;
                        automatic logic signed [15:0] expected = signed'(golden_mem[golden_idx]);
                        automatic logic signed [15:0] got      = coeff_out[15:0];
                        automatic int tolerance = 2;  // Allow ±2 LSB for rounding

                        total_compared++;
                        $fwrite(fd, "%04X\n", got);

                        // Debug: print first 16 values of block 0
                        if (block_num == 0 && block_coeff_idx < 16)
                            $display("DEBUG blk0[%0d]: got=%0d (0x%04X) exp=%0d (0x%04X) x?=%0b",
                                     block_coeff_idx, $signed(got), got,
                                     $signed(expected), expected, $isunknown(got));

                        if ($isunknown(got)) begin
                            $display("UNKNOWN block=%0d idx=%0d: coeff_out contains X/Z",
                                     block_num, block_coeff_idx);
                            mismatches++;
                        end else if ($signed(got - expected) > tolerance || $signed(got - expected) < -tolerance) begin
                            $display("MISMATCH block=%0d idx=%0d: got=%0d (0x%04X), expected=%0d (0x%04X), diff=%0d",
                                     block_num, block_coeff_idx,
                                     $signed(got), got,
                                     $signed(expected), expected,
                                     $signed(got) - $signed(expected));
                            mismatches++;
                            if (mismatches > 10) begin
                                $fatal(1, "Too many mismatches (>10), aborting");
                            end
                        end
                    end
                    block_coeff_idx++;
                end
            end
            coeff_rd = 0;

            // Wait for block_done
            while (!block_done) @(posedge clk); #1;

            $display("Block %0d complete", block_num);
        end

        // Final report
        if (mismatches == 0)
            $display("PASS: all %0d coefficients match golden reference (tolerance ±2 LSB)", total_compared);
        else
            $fatal(1, "FAIL: %0d mismatches out of %0d coefficients", mismatches, total_compared);

        $fclose(fd);
        $finish;
    end

    // Watchdog: generous timeout for full image processing
    initial begin
        #500000000;
        $fatal(1, "TIMEOUT: simulation took too long");
    end

endmodule
