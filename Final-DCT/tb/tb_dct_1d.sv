// tb_dct_1d.sv - 1D DCT engine unit testbench
// Feeds known 8-sample vectors, compares output to hand-calculated reference values
// Uses the same Q2.14 cosine coefficients as the ROM
`timescale 1ns/1ps
module tb_dct_1d;

    parameter int DATA_WIDTH      = 16;
    parameter int COEFF_WIDTH     = 16;
    parameter int ACCUM_WIDTH     = 32;
    parameter int FRAC_BITS       = 14;
    parameter int PARALLEL        = 0;
    parameter int PIPELINE_STAGES = 1;

    logic                          clk, rst_n;
    logic                          start, x_valid;
    logic signed [DATA_WIDTH-1:0]  x_in;
    logic signed [DATA_WIDTH-1:0]  y_out;
    logic                          y_valid, done, ready;

    dct_1d_engine #(
        .DATA_WIDTH      (DATA_WIDTH),
        .COEFF_WIDTH     (COEFF_WIDTH),
        .ACCUM_WIDTH     (ACCUM_WIDTH),
        .FRAC_BITS       (FRAC_BITS),
        .PARALLEL        (PARALLEL),
        .PIPELINE_STAGES (PIPELINE_STAGES)
    ) dut (.*);

    always #5 clk = ~clk;

    // ---- Golden reference computation ----
    // Q2.14 cosine table (same values as coefficient_rom.sv)
    int C_rom [0:63];
    initial begin
        // k=0: all 5793
        C_rom[ 0]=5793;  C_rom[ 1]=5793;  C_rom[ 2]=5793;  C_rom[ 3]=5793;
        C_rom[ 4]=5793;  C_rom[ 5]=5793;  C_rom[ 6]=5793;  C_rom[ 7]=5793;
        // k=1
        C_rom[ 8]=8035;  C_rom[ 9]=6812;  C_rom[10]=4552;  C_rom[11]=1598;
        C_rom[12]=-1598; C_rom[13]=-4552; C_rom[14]=-6812; C_rom[15]=-8035;
        // k=2
        C_rom[16]=7568;  C_rom[17]=3135;  C_rom[18]=-3135; C_rom[19]=-7568;
        C_rom[20]=-7568; C_rom[21]=-3135; C_rom[22]=3135;  C_rom[23]=7568;
        // k=3
        C_rom[24]=6812;  C_rom[25]=-1598; C_rom[26]=-8035; C_rom[27]=-4552;
        C_rom[28]=4552;  C_rom[29]=8035;  C_rom[30]=1598;  C_rom[31]=-6812;
        // k=4
        C_rom[32]=5793;  C_rom[33]=-5793; C_rom[34]=-5793; C_rom[35]=5793;
        C_rom[36]=5793;  C_rom[37]=-5793; C_rom[38]=-5793; C_rom[39]=5793;
        // k=5
        C_rom[40]=4552;  C_rom[41]=-8035; C_rom[42]=1598;  C_rom[43]=6812;
        C_rom[44]=-6812; C_rom[45]=-1598; C_rom[46]=8035;  C_rom[47]=-4552;
        // k=6
        C_rom[48]=3135;  C_rom[49]=-7568; C_rom[50]=7568;  C_rom[51]=-3135;
        C_rom[52]=-3135; C_rom[53]=7568;  C_rom[54]=-7568; C_rom[55]=3135;
        // k=7
        C_rom[56]=1598;  C_rom[57]=-4552; C_rom[58]=6812;  C_rom[59]=-8035;
        C_rom[60]=8035;  C_rom[61]=-6812; C_rom[62]=4552;  C_rom[63]=-1598;
    end

    // Compute expected 1D DCT output for a given input vector
    function automatic void compute_golden(
        input  int x[8],
        output int y[8]
    );
        longint acc;
        for (int k = 0; k < 8; k++) begin
            acc = 0;
            for (int n = 0; n < 8; n++) begin
                acc = acc + longint'(x[n]) * longint'(C_rom[k*8 + n]);
            end
            // Round then shift
            y[k] = int'((acc + (1 <<< (FRAC_BITS-1))) >>> FRAC_BITS);
            // Clamp to DATA_WIDTH
            if (y[k] > (2**(DATA_WIDTH-1)-1))  y[k] = 2**(DATA_WIDTH-1)-1;
            if (y[k] < -(2**(DATA_WIDTH-1)))   y[k] = -(2**(DATA_WIDTH-1));
        end
    endfunction

    // ---- Test task ----
    task automatic run_test(
        input string name,
        input int x[8]
    );
        int golden[8];
        int received[8];
        int rcv_idx;

        compute_golden(x, golden);
        rcv_idx = 0;

        // Wait for ready
        wait (ready);
        @(posedge clk); #1;

        // Pulse start
        start = 1;
        @(posedge clk); #1;
        start = 0;

        // Feed 8 input samples
        for (int i = 0; i < 8; i++) begin
            x_in    = DATA_WIDTH'(x[i]);
            x_valid = 1;
            @(posedge clk); #1;
        end
        x_valid = 0;
        x_in    = '0;

        // Collect 8 output coefficients
        while (rcv_idx < 8) begin
            @(posedge clk); #1;
            if (y_valid) begin
                $display("DBG: y_valid at t=%0t, y_out=%b (%0d) x?=%b", $time, y_out, $signed(y_out), $isunknown(y_out));
                received[rcv_idx] = $signed(y_out);
                if (received[rcv_idx] !== golden[rcv_idx]) begin
                    $fatal(1, "FAIL %s: y[%0d] got %0d, expected %0d",
                           name, rcv_idx, received[rcv_idx], golden[rcv_idx]);
                end
                rcv_idx++;
            end
        end
        $display("PASS %s", name);
    endtask

    // ---- Main test sequence ----
    initial begin
        clk = 0; rst_n = 0; start = 0; x_valid = 0; x_in = '0;
        repeat (3) @(posedge clk);
        #1; rst_n = 1;

        // Test 1: DC input — all 128 (uniform)
        // Expected: y[0] = 128 * 8 * alpha_0 = 128 * 8 * sqrt(1/8) ≈ 362 (fixed-point)
        // y[1..7] should be 0
        begin
            automatic int x1[8] = '{128, 128, 128, 128, 128, 128, 128, 128};
            run_test("dc_uniform", x1);
        end

        // Test 2: Ramp input
        begin
            automatic int x2[8] = '{0, 32, 64, 96, 128, 160, 192, 224};
            run_test("ramp", x2);
        end

        // Test 3: Alternating +/- pattern
        begin
            automatic int x3[8] = '{100, -100, 100, -100, 100, -100, 100, -100};
            run_test("alternating", x3);
        end

        // Test 4: Single impulse at n=0
        begin
            automatic int x4[8] = '{255, 0, 0, 0, 0, 0, 0, 0};
            run_test("impulse", x4);
        end

        // Test 5: Typical pixel values
        begin
            automatic int x5[8] = '{52, 55, 61, 66, 70, 61, 64, 73};
            run_test("typical_pixels", x5);
        end

        // Test 6: back-to-back transforms (no idle gap)
        begin
            automatic int x6a[8] = '{200, 200, 200, 200, 200, 200, 200, 200};
            automatic int x6b[8] = '{10, 20, 30, 40, 50, 60, 70, 80};
            run_test("back2back_a", x6a);
            run_test("back2back_b", x6b);
        end

        $display("All 1D DCT engine tests PASSED");
        $finish;
    end

    // Watchdog
    initial begin
        #100000;
        $fatal(1, "TIMEOUT: simulation took too long");
    end

endmodule
