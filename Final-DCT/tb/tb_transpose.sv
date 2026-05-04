// tb_transpose.sv - transpose buffer testbench
// Write a known 8x8 matrix row by row, read out column by column, verify transposition
`timescale 1ns/1ps
module tb_transpose;

    parameter int DATA_WIDTH = 16;

    logic                          clk, rst_n;
    logic signed [DATA_WIDTH-1:0]  wr_data;
    logic                          wr_valid;
    logic                          wr_done;
    logic signed [DATA_WIDTH-1:0]  rd_data;
    logic                          rd_en;
    logic                          rd_valid;
    logic                          rd_done;
    logic                          ready;

    transpose_buffer #(.DATA_WIDTH(DATA_WIDTH)) dut (.*);

    always #5 clk = ~clk;

    // Known test matrix (row-major)
    logic signed [DATA_WIDTH-1:0] test_matrix [0:7][0:7];

    initial begin
        // Fill with distinct values: matrix[r][c] = r*10 + c + 1
        for (int r = 0; r < 8; r++)
            for (int c = 0; c < 8; c++)
                test_matrix[r][c] = DATA_WIDTH'(r * 10 + c + 1);
    end

    initial begin
        clk = 0; rst_n = 0; wr_valid = 0; wr_data = '0; rd_en = 0;
        repeat (3) @(posedge clk);
        #1; rst_n = 1;

        // ---- Test 1: Write row-major, read column-major ----
        $display("--- Test 1: Basic transpose ---");

        // Write phase: send 64 values row by row
        @(posedge clk); #1;
        for (int r = 0; r < 8; r++) begin
            for (int c = 0; c < 8; c++) begin
                wr_data  = test_matrix[r][c];
                wr_valid = 1;
                @(posedge clk); #1;
            end
        end
        wr_valid = 0;

        // Wait for write to complete
        @(posedge clk); #1;

        // Read phase: expect column-major order
        // Column 0: matrix[0][0], matrix[1][0], ..., matrix[7][0]
        // Column 1: matrix[0][1], matrix[1][1], ..., matrix[7][1]
        // etc.
        for (int c = 0; c < 8; c++) begin
            for (int r = 0; r < 8; r++) begin
                if (!rd_valid)
                    $fatal(1, "FAIL: rd_valid not asserted at col=%0d, row=%0d", c, r);
                if (rd_data !== test_matrix[r][c])
                    $fatal(1, "FAIL: transpose[%0d][%0d] got %0d, expected %0d (matrix[%0d][%0d])",
                           c, r, rd_data, test_matrix[r][c], r, c);
                rd_en = 1;
                @(posedge clk); #1;
            end
        end
        rd_en = 0;
        $display("PASS: basic transpose verified");

        // ---- Test 2: Back-to-back operation ----
        $display("--- Test 2: Back-to-back ---");

        // Wait for ready
        wait (ready);
        @(posedge clk); #1;

        // Write second pattern: matrix2[r][c] = (7-r)*10 + (7-c)
        for (int r = 0; r < 8; r++) begin
            for (int c = 0; c < 8; c++) begin
                wr_data  = DATA_WIDTH'((7 - r) * 10 + (7 - c));
                wr_valid = 1;
                @(posedge clk); #1;
            end
        end
        wr_valid = 0;
        @(posedge clk); #1;

        // Read and verify
        for (int c = 0; c < 8; c++) begin
            for (int r = 0; r < 8; r++) begin
                begin
                    automatic int expected = (7 - r) * 10 + (7 - c);
                    if (rd_data !== DATA_WIDTH'(expected))
                        $fatal(1, "FAIL: back2back transpose[%0d][%0d] got %0d, expected %0d",
                               c, r, rd_data, expected);
                end
                rd_en = 1;
                @(posedge clk); #1;
            end
        end
        rd_en = 0;
        $display("PASS: back-to-back transpose verified");

        // ---- Test 3: Negative values ----
        $display("--- Test 3: Signed values ---");
        wait (ready);
        @(posedge clk); #1;

        for (int r = 0; r < 8; r++) begin
            for (int c = 0; c < 8; c++) begin
                wr_data  = DATA_WIDTH'(signed'((r - 4) * 100 + (c - 4) * 10));
                wr_valid = 1;
                @(posedge clk); #1;
            end
        end
        wr_valid = 0;
        @(posedge clk); #1;

        for (int c = 0; c < 8; c++) begin
            for (int r = 0; r < 8; r++) begin
                begin
                    automatic int expected = (r - 4) * 100 + (c - 4) * 10;
                    if (rd_data !== DATA_WIDTH'(signed'(expected)))
                        $fatal(1, "FAIL: signed transpose[%0d][%0d] got %0d, expected %0d",
                               c, r, $signed(rd_data), expected);
                end
                rd_en = 1;
                @(posedge clk); #1;
            end
        end
        rd_en = 0;
        $display("PASS: signed transpose verified");

        $display("All transpose buffer tests PASSED");
        $finish;
    end

    // Watchdog
    initial begin
        #50000;
        $fatal(1, "TIMEOUT");
    end

endmodule
