// tb_coefficient_rom.sv - verify all 64 Q2.14 ROM entries against MATLAB golden values
`timescale 1ns/1ps
module tb_coefficient_rom;

    logic        clk;
    logic [5:0]  addr;
    logic signed [15:0] data_out;

    coefficient_rom dut (.*);

    always #5 clk = ~clk;

    // Expected values: MATLAB round(alpha_k * cos(pi*(2n+1)*k/16) * 16384)
    // Flat array [k*8 + n]
    logic signed [15:0] expected [0:63];

    initial begin
        // k=0
        expected[ 0]=16'sh16A1; expected[ 1]=16'sh16A1; expected[ 2]=16'sh16A1; expected[ 3]=16'sh16A1;
        expected[ 4]=16'sh16A1; expected[ 5]=16'sh16A1; expected[ 6]=16'sh16A1; expected[ 7]=16'sh16A1;
        // k=1
        expected[ 8]=16'sh1F63; expected[ 9]=16'sh1A9C; expected[10]=16'sh11C8; expected[11]=16'sh063E;
        expected[12]=16'shF9C2; expected[13]=16'shEE38; expected[14]=16'shE564; expected[15]=16'shE09D;
        // k=2
        expected[16]=16'sh1D90; expected[17]=16'sh0C3F; expected[18]=16'shF3C1; expected[19]=16'shE270;
        expected[20]=16'shE270; expected[21]=16'shF3C1; expected[22]=16'sh0C3F; expected[23]=16'sh1D90;
        // k=3
        expected[24]=16'sh1A9C; expected[25]=16'shF9C2; expected[26]=16'shE09D; expected[27]=16'shEE38;
        expected[28]=16'sh11C8; expected[29]=16'sh1F63; expected[30]=16'sh063E; expected[31]=16'shE564;
        // k=4
        expected[32]=16'sh16A1; expected[33]=16'shE95F; expected[34]=16'shE95F; expected[35]=16'sh16A1;
        expected[36]=16'sh16A1; expected[37]=16'shE95F; expected[38]=16'shE95F; expected[39]=16'sh16A1;
        // k=5
        expected[40]=16'sh11C8; expected[41]=16'shE09D; expected[42]=16'sh063E; expected[43]=16'sh1A9C;
        expected[44]=16'shE564; expected[45]=16'shF9C2; expected[46]=16'sh1F63; expected[47]=16'shEE38;
        // k=6
        expected[48]=16'sh0C3F; expected[49]=16'shE270; expected[50]=16'sh1D90; expected[51]=16'shF3C1;
        expected[52]=16'shF3C1; expected[53]=16'sh1D90; expected[54]=16'shE270; expected[55]=16'sh0C3F;
        // k=7
        expected[56]=16'sh063E; expected[57]=16'shEE38; expected[58]=16'sh1A9C; expected[59]=16'shE09D;
        expected[60]=16'sh1F63; expected[61]=16'shE564; expected[62]=16'sh11C8; expected[63]=16'shF9C2;
    end

    initial begin
        clk = 0; addr = '0;
        @(posedge clk); #1;

        for (int i = 0; i < 64; i++) begin
            addr = 6'(i);
            @(posedge clk); #1;   // synchronous ROM: output valid one cycle after addr
            if (data_out !== expected[i])
                $fatal(1, "FAIL addr=%0d (k=%0d,n=%0d): got %0d, expected %0d",
                       i, i/8, i%8, data_out, $signed(expected[i]));
        end

        $display("PASS: all 64 coefficient ROM entries match golden values");
        $finish;
    end

endmodule
