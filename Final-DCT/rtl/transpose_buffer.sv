// transpose_buffer.sv - 8x8 corner-turning memory between 1D DCT passes
// Write row-wise (from row-pass DCT output), read column-wise (for column-pass DCT input)
module transpose_buffer #(
    parameter int DATA_WIDTH = 16
) (
    input  logic                          clk,
    input  logic                          rst_n,
    // Write port (row-wise): one coefficient per cycle
    input  logic signed [DATA_WIDTH-1:0]  wr_data,
    input  logic                          wr_valid,
    output logic                          wr_done,    // 64 values written (full 8x8)
    // Read port (column-wise): one coefficient per cycle
    output logic signed [DATA_WIDTH-1:0]  rd_data,
    input  logic                          rd_en,      // consume current value & advance
    output logic                          rd_valid,   // data available to read
    output logic                          rd_done,    // 64 values read (full 8x8)
    // Status
    output logic                          ready       // ready to accept writes
);

    // 64-entry memory (flattened from 8x8 to avoid Quartus 2D RAM crashes)
    logic signed [DATA_WIDTH-1:0] mem [0:63];

    // Write counters: fill row-wise
    logic [2:0] wr_row, wr_col;
    logic [5:0] wr_cnt;      // total writes (0..63)

    // Read counters: drain column-wise (row first within each column)
    logic [2:0] rd_row, rd_col;
    logic [5:0] rd_cnt;

    // States
    typedef enum logic [1:0] {
        S_IDLE  = 2'd0,
        S_WRITE = 2'd1,
        S_READ  = 2'd2
    } state_t;
    state_t state;

    // Combinational read output: always present mem[{rd_row, rd_col}]
    assign rd_data  = mem[{rd_row, rd_col}];
    assign rd_valid = (state == S_READ);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            wr_row   <= '0;
            wr_col   <= '0;
            wr_cnt   <= '0;
            rd_row   <= '0;
            rd_col   <= '0;
            rd_cnt   <= '0;
            wr_done  <= 1'b0;
            rd_done  <= 1'b0;
        end else begin
            wr_done  <= 1'b0;
            rd_done  <= 1'b0;

            case (state)
                S_IDLE: begin
                    wr_row <= '0;
                    wr_col <= '0;
                    wr_cnt <= '0;
                    rd_row <= '0;
                    rd_col <= '0;
                    rd_cnt <= '0;
                    // Transition to WRITE when first valid data arrives
                    if (wr_valid) begin
                        mem[6'd0] <= wr_data;
                        wr_col <= 3'd1;
                        wr_cnt <= 6'd1;
                        state  <= S_WRITE;
                    end
                end

                S_WRITE: begin
                    if (wr_valid) begin
                        mem[{wr_row, wr_col}] <= wr_data;
                        wr_cnt <= wr_cnt + 1;

                        if (wr_col == 3'd7) begin
                            wr_col <= '0;
                            wr_row <= wr_row + 1;
                        end else begin
                            wr_col <= wr_col + 1;
                        end

                        // Check if this was the last write (64th value)
                        if (wr_cnt == 6'd63) begin
                            wr_done <= 1'b1;
                            state   <= S_READ;
                            rd_row  <= '0;
                            rd_col  <= '0;
                            rd_cnt  <= '0;
                        end
                    end
                end

                S_READ: begin
                    // Combinational output: rd_data = mem[rd_row][rd_col]
                    // When rd_en is high, advance to next position (column-wise)
                    if (rd_en) begin
                        rd_cnt <= rd_cnt + 1;

                        if (rd_row == 3'd7) begin
                            rd_row <= '0;
                            rd_col <= rd_col + 1;
                        end else begin
                            rd_row <= rd_row + 1;
                        end

                        if (rd_cnt == 6'd63) begin
                            rd_done <= 1'b1;
                            state   <= S_IDLE;
                        end
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    assign ready = (state == S_IDLE) || (state == S_WRITE);

endmodule
