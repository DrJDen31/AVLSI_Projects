// tb_quantizer.sv - quantizer testbench
// Apply known DCT coefficients, compare quantized output to hand-calculated reference
`timescale 1ns/1ps
module tb_quantizer;

    parameter int DATA_WIDTH = 16;

    logic                          clk, rst_n;
    logic signed [DATA_WIDTH-1:0]  coeff_in;
    logic                          coeff_valid;
    logic signed [DATA_WIDTH-1:0]  quant_out;
    logic                          quant_valid, done, ready;

    quantizer #(.DATA_WIDTH(DATA_WIDTH)) dut (.*);

    always #5 clk = ~clk;

    // Standard JPEG luminance Q-table for golden model
    int Q_table [0:63];
    initial begin
        Q_table[ 0]=16; Q_table[ 1]=11; Q_table[ 2]=10; Q_table[ 3]=16;
        Q_table[ 4]=24; Q_table[ 5]=40; Q_table[ 6]=51; Q_table[ 7]=61;
        Q_table[ 8]=12; Q_table[ 9]=12; Q_table[10]=14; Q_table[11]=19;
        Q_table[12]=26; Q_table[13]=58; Q_table[14]=60; Q_table[15]=55;
        Q_table[16]=14; Q_table[17]=13; Q_table[18]=16; Q_table[19]=24;
        Q_table[20]=40; Q_table[21]=57; Q_table[22]=69; Q_table[23]=56;
        Q_table[24]=14; Q_table[25]=17; Q_table[26]=22; Q_table[27]=29;
        Q_table[28]=51; Q_table[29]=87; Q_table[30]=80; Q_table[31]=62;
        Q_table[32]=18; Q_table[33]=22; Q_table[34]=37; Q_table[35]=56;
        Q_table[36]=68; Q_table[37]=109; Q_table[38]=103; Q_table[39]=77;
        Q_table[40]=24; Q_table[41]=35; Q_table[42]=55; Q_table[43]=64;
        Q_table[44]=81; Q_table[45]=104; Q_table[46]=113; Q_table[47]=92;
        Q_table[48]=49; Q_table[49]=64; Q_table[50]=78; Q_table[51]=87;
        Q_table[52]=103; Q_table[53]=121; Q_table[54]=120; Q_table[55]=101;
        Q_table[56]=72; Q_table[57]=92; Q_table[58]=95; Q_table[59]=98;
        Q_table[60]=112; Q_table[61]=100; Q_table[62]=103; Q_table[63]=99;
    end

    // Golden rounding division
    function automatic int round_div(int val, int divisor);
        if (val >= 0)
            return (val + divisor/2) / divisor;
        else
            return (val - divisor/2) / divisor;
    endfunction

    // Test task: feed 64 coefficients and check quantized output
    task automatic run_test(
        input string name,
        input int coeffs [0:63]
    );
        int expected [0:63];
        int received [0:63];
        int rcv_idx;

        // Compute golden
        for (int i = 0; i < 64; i++)
            expected[i] = round_div(coeffs[i], Q_table[i]);

        rcv_idx = 0;

        // Feed 64 coefficients
        for (int i = 0; i < 64; i++) begin
            coeff_in    = DATA_WIDTH'(signed'(coeffs[i]));
            coeff_valid = 1;
            @(posedge clk); #1;
        end
        coeff_valid = 0;

        // Collect outputs (2-cycle pipeline latency)
        while (rcv_idx < 64) begin
            @(posedge clk); #1;
            if (quant_valid) begin
                received[rcv_idx] = int'(signed'(quant_out));
                if (received[rcv_idx] !== expected[rcv_idx])
                    $fatal(1, "FAIL %s: idx=%0d got %0d, expected %0d (coeff=%0d, Q=%0d)",
                           name, rcv_idx, received[rcv_idx], expected[rcv_idx],
                           coeffs[rcv_idx], Q_table[rcv_idx]);
                rcv_idx++;
            end
        end
        $display("PASS %s", name);
    endtask

    initial begin
        clk = 0; rst_n = 0; coeff_valid = 0; coeff_in = '0;
        repeat (3) @(posedge clk);
        #1; rst_n = 1;
        @(posedge clk); #1;

        // Test 1: All-zero coefficients
        begin
            automatic int c1 [0:63];
            for (int i = 0; i < 64; i++) c1[i] = 0;
            run_test("all_zero", c1);
        end

        // Wait for ready between tests
        wait (ready);
        @(posedge clk); #1;

        // Test 2: Positive ramp (increasing values)
        begin
            automatic int c2 [0:63];
            for (int i = 0; i < 64; i++) c2[i] = (i + 1) * 10;
            run_test("pos_ramp", c2);
        end

        wait (ready);
        @(posedge clk); #1;

        // Test 3: Negative values
        begin
            automatic int c3 [0:63];
            for (int i = 0; i < 64; i++) c3[i] = -((i + 1) * 5);
            run_test("neg_values", c3);
        end

        wait (ready);
        @(posedge clk); #1;

        // Test 4: Typical DCT coefficient magnitudes
        begin
            automatic int c4 [0:63];
            // DC coefficient large, AC coefficients decreasing
            c4[0] = 1024;
            for (int i = 1; i < 64; i++) c4[i] = 500 / (i + 1);
            run_test("typical_dct", c4);
        end

        wait (ready);
        @(posedge clk); #1;

        // Test 5: Mixed sign
        begin
            automatic int c5 [0:63];
            for (int i = 0; i < 64; i++)
                c5[i] = (i % 2 == 0) ? (i * 15) : (-(i * 15));
            run_test("mixed_sign", c5);
        end

        $display("All quantizer tests PASSED");
        $finish;
    end

    // Watchdog
    initial begin
        #200000;
        $fatal(1, "TIMEOUT");
    end

endmodule
