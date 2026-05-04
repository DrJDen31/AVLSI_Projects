// pixel_block_buffer.sv - input 8x8 block staging
// Accepts a stream of pixel values and presents them row-by-row to the DCT engine
// Loads 64 pixels (8x8 block), then signals ready for the DCT engine to consume
//
// Read interface: combinational. sample_out = mem[rd_ptr] whenever reading=1.
// When sample_req is asserted and reading=1, rd_ptr advances on the next clock
// edge and sample_valid is asserted for one cycle.
module pixel_block_buffer #(
    parameter int DATA_WIDTH = 16
) (
    input  logic                          clk,
    input  logic                          rst_n,
    // External pixel input
    input  logic [7:0]                    pixel_in,     // 8-bit unsigned pixel
    input  logic                          pixel_valid,
    output logic                          pixel_ready,  // Can accept pixels
    // DCT engine interface
    output logic signed [DATA_WIDTH-1:0]  sample_out,   // Signed sample to DCT
    output logic                          sample_valid,
    input  logic                          sample_req,   // Request: consume current sample & advance
    // Status
    output logic                          block_loaded, // Full 8x8 block is loaded
    output logic                          block_done    // All 64 samples consumed by engine
);

    // 8x8 storage (row-major)
    logic signed [DATA_WIDTH-1:0] mem [0:63];

    // Write pointer
    logic [5:0] wr_ptr;

    // Read pointer
    logic [5:0] rd_ptr;
    logic       reading;

    // Combinational read output: always present current sample
    assign sample_out   = mem[rd_ptr];
    assign sample_valid = reading;

    // Write side: accept pixels until 64 are loaded
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr       <= '0;
            block_loaded <= 1'b0;
        end else if (block_done) begin
            // Reset for next block
            wr_ptr       <= '0;
            block_loaded <= 1'b0;
        end else if (pixel_valid && !block_loaded) begin
            // Store pixel as signed (zero-extend 8-bit unsigned to DATA_WIDTH signed)
            mem[wr_ptr] <= DATA_WIDTH'(signed'({1'b0, pixel_in}));
            if (wr_ptr == 6'd63)
                block_loaded <= 1'b1;
            wr_ptr <= wr_ptr + 1;
        end
    end

    assign pixel_ready = !block_loaded;

    // Read side: advance pointer when sample_req is high
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr     <= '0;
            reading    <= 1'b0;
            block_done <= 1'b0;
        end else begin
            block_done <= 1'b0;

            if (block_done) begin
                rd_ptr  <= '0;
                reading <= 1'b0;
            end else if (block_loaded && !reading) begin
                reading <= 1'b1;
                rd_ptr  <= '0;
            end else if (reading && sample_req) begin
                if (rd_ptr == 6'd63) begin
                    reading    <= 1'b0;
                    block_done <= 1'b1;
                end
                rd_ptr <= rd_ptr + 1;
            end
        end
    end

endmodule
