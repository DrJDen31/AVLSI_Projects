// output_buffer.sv - output coefficient staging
// Collects 64 quantized coefficients and exposes them at the output port
// Coefficients arrive in column-major order from the second DCT pass,
// stored and presented in row-major order for comparison with MATLAB golden
module output_buffer #(
    parameter int DATA_WIDTH = 16
) (
    input  logic                          clk,
    input  logic                          rst_n,
    // Input from quantizer
    input  logic signed [DATA_WIDTH-1:0]  coeff_in,
    input  logic                          coeff_valid,
    // Output interface
    output logic signed [DATA_WIDTH-1:0]  coeff_out,
    output logic                          out_valid,
    input  logic                          out_rd,       // Consumer reads one coefficient
    // Status
    output logic                          block_ready,  // Full 8x8 block available for reading
    output logic                          block_done    // All 64 coefficients read out
);

    // Storage (row-major)
    logic signed [DATA_WIDTH-1:0] mem [0:63];

    // Write side
    logic [5:0] wr_ptr;
    logic       full;

    // Read side
    logic [5:0] rd_ptr;
    logic       reading;

    // Write: accept coefficients sequentially
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr      <= '0;
            full        <= 1'b0;
            block_ready <= 1'b0;
        end else if (block_done) begin
            wr_ptr      <= '0;
            full        <= 1'b0;
            block_ready <= 1'b0;
        end else if (coeff_valid && !full) begin
            mem[{wr_ptr[2:0], wr_ptr[5:3]}] <= coeff_in;
            if (wr_ptr == 6'd63) begin
                full        <= 1'b1;
                block_ready <= 1'b1;
            end
            wr_ptr <= wr_ptr + 1;
        end
    end

    // Read: present coefficients one at a time
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr     <= '0;
            reading    <= 1'b0;
            out_valid  <= 1'b0;
            coeff_out  <= '0;
            block_done <= 1'b0;
        end else begin
            out_valid  <= 1'b0;
            block_done <= 1'b0;

            if (block_ready && !reading) begin
                reading <= 1'b1;
                rd_ptr  <= '0;
            end

            if (reading && out_rd) begin
                coeff_out <= mem[rd_ptr];
                out_valid <= 1'b1;
                if (rd_ptr == 6'd63) begin
                    reading    <= 1'b0;
                    block_done <= 1'b1;
                end
                rd_ptr <= rd_ptr + 1;
            end
        end
    end

endmodule
