// tb_mac_unit.sv - MAC unit testbench
`timescale 1ns/1ps
module tb_mac_unit;

    parameter int DATA_WIDTH  = 16;
    parameter int COEFF_WIDTH = 16;
    parameter int ACCUM_WIDTH = 32;

    logic                           clk, rst_n, clr, en;
    logic signed [DATA_WIDTH-1:0]   data_in;
    logic signed [COEFF_WIDTH-1:0]  coeff_in;
    logic signed [ACCUM_WIDTH-1:0]  accum_out;

    mac_unit #(
        .DATA_WIDTH (DATA_WIDTH),
        .COEFF_WIDTH(COEFF_WIDTH),
        .ACCUM_WIDTH(ACCUM_WIDTH)
    ) dut (.*);

    always #5 clk = ~clk;

    task automatic apply_and_check(
        input string              test_name,
        input logic signed [DATA_WIDTH-1:0]  d[8],
        input logic signed [COEFF_WIDTH-1:0] c[8],
        input logic signed [ACCUM_WIDTH-1:0] expected
    );
        // clear accumulator
        @(posedge clk); #1;
        clr = 1; en = 0;
        @(posedge clk); #1;
        clr = 0;

        // feed 8 MAC cycles
        for (int i = 0; i < 8; i++) begin
            data_in  = d[i];
            coeff_in = c[i];
            en = 1;
            @(posedge clk); #1;
        end
        en = 0;

        if (accum_out !== expected)
            $fatal(1, "FAIL %s: got %0d, expected %0d", test_name, accum_out, expected);
        else
            $display("PASS %s: accum=%0d", test_name, accum_out);
    endtask

    initial begin
        clk = 0; rst_n = 0; clr = 0; en = 0;
        data_in = '0; coeff_in = '0;
        @(posedge clk); #1;
        rst_n = 1;

        // Test 1: pixel=100, coeff=16384 (Q2.14 = 1.0), 8 identical MACs
        // expected = 8 * 100 * 16384 = 13107200
        begin
            automatic logic signed [DATA_WIDTH-1:0]  d1[8] = '{8{16'sd100}};
            automatic logic signed [COEFF_WIDTH-1:0] c1[8] = '{8{16'sd16384}};
            apply_and_check("unity_coeff", d1, c1, 32'sd13107200);
        end

        // Test 2: pixel=128, coeff=-16384 (Q2.14 = -1.0), 8 MACs
        // expected = 8 * 128 * (-16384) = -16777216
        begin
            automatic logic signed [DATA_WIDTH-1:0]  d2[8] = '{8{16'sd128}};
            automatic logic signed [COEFF_WIDTH-1:0] c2[8] = '{8{-16'sd16384}};
            apply_and_check("neg_coeff", d2, c2, -32'sd16777216);
        end

        // Test 3: mixed sign pixels, coeff=8192 (Q2.14 = 0.5)
        // pixels: 10, -10, 20, -20, 30, -30, 40, -40 → sum=0, expected=0
        begin
            automatic logic signed [DATA_WIDTH-1:0]  d3[8] = '{16'sd10, -16'sd10, 16'sd20, -16'sd20,
                                                                16'sd30, -16'sd30, 16'sd40, -16'sd40};
            automatic logic signed [COEFF_WIDTH-1:0] c3[8] = '{8{16'sd8192}};
            apply_and_check("cancel_pixels", d3, c3, 32'sd0);
        end

        // Test 4: reset clears accumulator
        // Accumulate one cycle, then rst_n=0, check zero
        @(posedge clk); #1;
        clr = 1; en = 0;
        @(posedge clk); #1;
        clr = 0;
        data_in = 16'sd255; coeff_in = 16'sd16384; en = 1;
        @(posedge clk); #1;
        en = 0;
        rst_n = 0;
        @(posedge clk); #1;
        rst_n = 1;
        @(posedge clk); #1;
        if (accum_out !== '0)
            $fatal(1, "FAIL reset: accum not cleared, got %0d", accum_out);
        else
            $display("PASS reset: accum=0 after rst_n");

        $display("All MAC unit tests PASSED");
        $finish;
    end

endmodule
