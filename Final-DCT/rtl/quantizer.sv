// quantizer.sv - JPEG luminance Q-table divider
// Applies standard JPEG luminance quantization table to 8x8 DCT coefficients
// Operation: quantized[i] = round(coeff[i] / Q[i])
// Uses signed division with rounding toward nearest integer
module quantizer #(
    parameter int DATA_WIDTH = 16   // Input/output coefficient width
) (
    input  logic                          clk,
    input  logic                          rst_n,
    // Input: stream of 64 coefficients (row-major order)
    input  logic signed [DATA_WIDTH-1:0]  coeff_in,
    input  logic                          coeff_valid,
    // Output: quantized coefficients
    output logic signed [DATA_WIDTH-1:0]  quant_out,
    output logic                          quant_valid,
    output logic                          done,       // All 64 coefficients quantized
    output logic                          ready
);

    // Standard JPEG luminance quantization table (QF=50)
    // Stored in row-major order: Q[row*8 + col]
    logic [7:0] Q_table [0:63];
    initial begin
        // Row 0
        Q_table[ 0]=8'd16; Q_table[ 1]=8'd11; Q_table[ 2]=8'd10; Q_table[ 3]=8'd16;
        Q_table[ 4]=8'd24; Q_table[ 5]=8'd40; Q_table[ 6]=8'd51; Q_table[ 7]=8'd61;
        // Row 1
        Q_table[ 8]=8'd12; Q_table[ 9]=8'd12; Q_table[10]=8'd14; Q_table[11]=8'd19;
        Q_table[12]=8'd26; Q_table[13]=8'd58; Q_table[14]=8'd60; Q_table[15]=8'd55;
        // Row 2
        Q_table[16]=8'd14; Q_table[17]=8'd13; Q_table[18]=8'd16; Q_table[19]=8'd24;
        Q_table[20]=8'd40; Q_table[21]=8'd57; Q_table[22]=8'd69; Q_table[23]=8'd56;
        // Row 3
        Q_table[24]=8'd14; Q_table[25]=8'd17; Q_table[26]=8'd22; Q_table[27]=8'd29;
        Q_table[28]=8'd51; Q_table[29]=8'd87; Q_table[30]=8'd80; Q_table[31]=8'd62;
        // Row 4
        Q_table[32]=8'd18; Q_table[33]=8'd22; Q_table[34]=8'd37; Q_table[35]=8'd56;
        Q_table[36]=8'd68; Q_table[37]=8'd109; Q_table[38]=8'd103; Q_table[39]=8'd77;
        // Row 5
        Q_table[40]=8'd24; Q_table[41]=8'd35; Q_table[42]=8'd55; Q_table[43]=8'd64;
        Q_table[44]=8'd81; Q_table[45]=8'd104; Q_table[46]=8'd113; Q_table[47]=8'd92;
        // Row 6
        Q_table[48]=8'd49; Q_table[49]=8'd64; Q_table[50]=8'd78; Q_table[51]=8'd87;
        Q_table[52]=8'd103; Q_table[53]=8'd121; Q_table[54]=8'd120; Q_table[55]=8'd101;
        // Row 7
        Q_table[56]=8'd72; Q_table[57]=8'd92; Q_table[58]=8'd95; Q_table[59]=8'd98;
        Q_table[60]=8'd112; Q_table[61]=8'd100; Q_table[62]=8'd103; Q_table[63]=8'd99;
    end

    // Index counter
    logic [5:0] idx;
    logic       active;

    // Division pipeline: 1-cycle latency
    // round(coeff / Q) = (coeff + Q/2) / Q  for positive, (coeff - Q/2) / Q for negative
    logic signed [DATA_WIDTH-1:0] coeff_r;
    logic [7:0]                   q_val;
    logic                         div_valid;
    logic [5:0]                   div_idx;

    // Stage 1: register inputs and look up Q value
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            coeff_r   <= '0;
            q_val     <= 8'd1;
            div_valid <= 1'b0;
            div_idx   <= '0;
        end else if (coeff_valid && active) begin
            coeff_r   <= coeff_in;
            q_val     <= Q_table[idx];
            div_valid <= 1'b1;
            div_idx   <= idx;
        end else begin
            div_valid <= 1'b0;
        end
    end

    // Stage 2: perform signed division with rounding
    logic signed [DATA_WIDTH-1:0] quant_r;
    logic                         quant_valid_r;
    logic                         done_r;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            quant_r       <= '0;
            quant_valid_r <= 1'b0;
            done_r        <= 1'b0;
        end else if (div_valid) begin
            // Signed rounding division
            if (coeff_r >= 0)
                quant_r <= DATA_WIDTH'((coeff_r + DATA_WIDTH'(q_val >>> 1)) / signed'({1'b0, q_val}));
            else
                quant_r <= DATA_WIDTH'((coeff_r - DATA_WIDTH'(q_val >>> 1)) / signed'({1'b0, q_val}));
            quant_valid_r <= 1'b1;
            done_r        <= (div_idx == 6'd63);
        end else begin
            quant_valid_r <= 1'b0;
            done_r        <= 1'b0;
        end
    end

    // Index counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            idx    <= '0;
            active <= 1'b1;
        end else if (done_r) begin
            idx    <= '0;
            active <= 1'b1;
        end else if (coeff_valid && active) begin
            if (idx == 6'd63)
                active <= 1'b0;
            else
                idx <= idx + 1;
        end
    end

    assign quant_out  = quant_r;
    assign quant_valid = quant_valid_r;
    assign done       = done_r;
    assign ready      = active;

endmodule
