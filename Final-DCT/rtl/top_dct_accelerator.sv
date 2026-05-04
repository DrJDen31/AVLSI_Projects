// top_dct_accelerator.sv - parameterized top (D1..D4 via PARALLEL / PIPELINE_STAGES)
// Forward path: pixel_in → pixel_block_buffer → dct_1d_engine (row pass) →
//               transpose_buffer → dct_1d_engine (col pass) → quantizer → output_buffer
module top_dct_accelerator #(
    parameter int DATA_WIDTH      = 16,
    parameter int COEFF_WIDTH     = 16,
    parameter int ACCUM_WIDTH     = 32,
    parameter int FRAC_BITS       = 14,
    parameter int PARALLEL        = 0,
    parameter int PIPELINE_STAGES = 1,
    parameter int SKIP_QUANTIZER  = 0    // 1=bypass quantizer (for golden comparison)
) (
    input  logic                          clk,
    input  logic                          rst_n,
    // Pixel input
    input  logic [7:0]                    pixel_in,
    input  logic                          pixel_valid,
    output logic                          pixel_ready,
    // Coefficient output
    output logic signed [DATA_WIDTH-1:0]  coeff_out,
    output logic                          coeff_valid,
    input  logic                          coeff_rd,
    // Status
    output logic                          block_ready,  // Output block available
    output logic                          block_done    // Output block fully read
);

    // =========================================================================
    // Internal signals
    // =========================================================================

    // Pixel block buffer → row-pass DCT engine
    logic signed [DATA_WIDTH-1:0] pbb_sample;
    logic                         pbb_sample_valid;
    logic                         pbb_sample_req;
    logic                         pbb_block_loaded;
    logic                         pbb_block_done;

    // Row-pass DCT engine
    logic                         row_start;
    logic signed [DATA_WIDTH-1:0] row_x_in;
    logic                         row_x_valid;
    logic signed [DATA_WIDTH-1:0] row_y_out;
    logic                         row_y_valid;
    logic                         row_done;
    logic                         row_ready;

    // Transpose buffer
    logic signed [DATA_WIDTH-1:0] tb_wr_data;
    logic                         tb_wr_valid;
    logic                         tb_wr_done;
    logic signed [DATA_WIDTH-1:0] tb_rd_data;
    logic                         tb_rd_en;
    logic                         tb_rd_valid;
    logic                         tb_rd_done;
    logic                         tb_ready;

    // Column-pass DCT engine
    logic                         col_start;
    logic signed [DATA_WIDTH-1:0] col_x_in;
    logic                         col_x_valid;
    logic signed [DATA_WIDTH-1:0] col_y_out;
    logic                         col_y_valid;
    logic                         col_done;
    logic                         col_ready;

    // Quantizer
    logic signed [DATA_WIDTH-1:0] q_coeff_in;
    logic                         q_coeff_valid;
    logic signed [DATA_WIDTH-1:0] q_quant_out;
    logic                         q_quant_valid;
    logic                         q_done;
    logic                         q_ready;

    // Output buffer
    logic signed [DATA_WIDTH-1:0] ob_coeff_in;
    logic                         ob_coeff_valid;

    // =========================================================================
    // Module instantiations
    // =========================================================================

    pixel_block_buffer #(.DATA_WIDTH(DATA_WIDTH)) u_pbb (
        .clk          (clk),
        .rst_n        (rst_n),
        .pixel_in     (pixel_in),
        .pixel_valid  (pixel_valid),
        .pixel_ready  (pixel_ready),
        .sample_out   (pbb_sample),
        .sample_valid (pbb_sample_valid),
        .sample_req   (pbb_sample_req),
        .block_loaded (pbb_block_loaded),
        .block_done   (pbb_block_done)
    );

    dct_1d_engine #(
        .DATA_WIDTH      (DATA_WIDTH),
        .COEFF_WIDTH     (COEFF_WIDTH),
        .ACCUM_WIDTH     (ACCUM_WIDTH),
        .FRAC_BITS       (FRAC_BITS),
        .PARALLEL        (PARALLEL),
        .PIPELINE_STAGES (PIPELINE_STAGES)
    ) u_dct_row (
        .clk     (clk),
        .rst_n   (rst_n),
        .start   (row_start),
        .x_in    (row_x_in),
        .x_valid (row_x_valid),
        .y_out   (row_y_out),
        .y_valid (row_y_valid),
        .done    (row_done),
        .ready   (row_ready)
    );

    transpose_buffer #(.DATA_WIDTH(DATA_WIDTH)) u_transpose (
        .clk      (clk),
        .rst_n    (rst_n),
        .wr_data  (tb_wr_data),
        .wr_valid (tb_wr_valid),
        .wr_done  (tb_wr_done),
        .rd_data  (tb_rd_data),
        .rd_en    (tb_rd_en),
        .rd_valid (tb_rd_valid),
        .rd_done  (tb_rd_done),
        .ready    (tb_ready)
    );

    dct_1d_engine #(
        .DATA_WIDTH      (DATA_WIDTH),
        .COEFF_WIDTH     (COEFF_WIDTH),
        .ACCUM_WIDTH     (ACCUM_WIDTH),
        .FRAC_BITS       (FRAC_BITS),
        .PARALLEL        (PARALLEL),
        .PIPELINE_STAGES (PIPELINE_STAGES)
    ) u_dct_col (
        .clk     (clk),
        .rst_n   (rst_n),
        .start   (col_start),
        .x_in    (col_x_in),
        .x_valid (col_x_valid),
        .y_out   (col_y_out),
        .y_valid (col_y_valid),
        .done    (col_done),
        .ready   (col_ready)
    );

    quantizer #(.DATA_WIDTH(DATA_WIDTH)) u_quantizer (
        .clk         (clk),
        .rst_n       (rst_n),
        .coeff_in    (q_coeff_in),
        .coeff_valid (q_coeff_valid),
        .quant_out   (q_quant_out),
        .quant_valid (q_quant_valid),
        .done        (q_done),
        .ready       (q_ready)
    );

    output_buffer #(.DATA_WIDTH(DATA_WIDTH)) u_output (
        .clk         (clk),
        .rst_n       (rst_n),
        .coeff_in    (ob_coeff_in),
        .coeff_valid (ob_coeff_valid),
        .coeff_out   (coeff_out),
        .out_valid   (coeff_valid),
        .out_rd      (coeff_rd),
        .block_ready (block_ready),
        .block_done  (block_done)
    );

    // =========================================================================
    // Top-level control FSM
    // =========================================================================
    typedef enum logic [3:0] {
        TOP_IDLE       = 4'd0,
        TOP_ROW_PASS   = 4'd2,   // Process 8 rows through row DCT
        TOP_TRANSPOSE  = 4'd3,   // Wait for transpose buffer to finish
        TOP_COL_PASS   = 4'd4,   // Process 8 columns through col DCT
        TOP_QUANTIZE   = 4'd5,   // Wait for quantizer to finish
        TOP_OUTPUT     = 4'd6    // Wait for output buffer to be read
    } top_state_t;
    top_state_t top_state;

    // Row pass sub-state: track which of the 8 rows we're processing
    logic [2:0] row_pass_cnt;     // which row (0..7) is being fed to row DCT
    logic [3:0] row_feed_cnt;     // sample count within row (0..8), use 4 bits to track completion
    logic       row_pass_feeding; // currently feeding samples to row DCT
    logic       row_pass_started; // start pulse sent for current row
    logic       row_waiting_done; // waiting for DCT engine to finish current row

    // Column pass sub-state
    logic [2:0] col_pass_cnt;
    logic [3:0] col_feed_cnt;     // 4 bits to track completion
    logic       col_pass_feeding;
    logic       col_pass_started;
    logic       col_waiting_done;

    // Intermediate storage for column pass input: transpose buffer reads go here
    logic signed [DATA_WIDTH-1:0] col_input_buf [0:7];
    logic [3:0] col_buf_wr_ptr;   // 4 bits to track completion
    logic       col_buf_ready;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            top_state        <= TOP_IDLE;
            row_pass_cnt     <= '0;
            row_feed_cnt     <= '0;
            row_pass_feeding <= 1'b0;
            row_pass_started <= 1'b0;
            row_waiting_done <= 1'b0;
            col_pass_cnt     <= '0;
            col_feed_cnt     <= '0;
            col_pass_feeding <= 1'b0;
            col_pass_started <= 1'b0;
            col_waiting_done <= 1'b0;
            col_buf_wr_ptr   <= '0;
            col_buf_ready    <= 1'b0;
        end else begin
            case (top_state)
                TOP_IDLE: begin
                    row_pass_cnt     <= '0;
                    row_pass_started <= 1'b0;
                    row_pass_feeding <= 1'b0;
                    row_waiting_done <= 1'b0;
                    if (pbb_block_loaded)
                        top_state <= TOP_ROW_PASS;
                end

                TOP_ROW_PASS: begin
                    // Phase 1: Send start pulse to DCT engine
                    if (!row_pass_started && !row_pass_feeding && !row_waiting_done && row_ready) begin
                        row_pass_started <= 1'b1;
                        row_feed_cnt     <= '0;
                        row_pass_feeding <= 1'b1;
                    end

                    // Phase 2: Feed 8 samples from pixel_block_buffer
                    // Count samples that DCT actually accepts (x_valid)
                    if (row_pass_feeding && pbb_sample_valid) begin
                        row_feed_cnt <= row_feed_cnt + 1;
                        if (row_feed_cnt == 4'd7) begin
                            row_pass_feeding <= 1'b0;
                            row_waiting_done <= 1'b1;
                        end
                    end

                    // Phase 3: Wait for DCT engine to finish processing
                    if (row_done) begin
                        row_pass_started <= 1'b0;
                        row_waiting_done <= 1'b0;
                        if (row_pass_cnt == 3'd7) begin
                            top_state <= TOP_TRANSPOSE;
                        end else begin
                            row_pass_cnt <= row_pass_cnt + 1;
                        end
                    end
                end

                TOP_TRANSPOSE: begin
                    // Transpose buffer auto-switches from write to read
                    col_pass_cnt     <= '0;
                    col_pass_started <= 1'b0;
                    col_pass_feeding <= 1'b0;
                    col_waiting_done <= 1'b0;
                    col_buf_wr_ptr   <= '0;
                    col_buf_ready    <= 1'b0;
                    top_state        <= TOP_COL_PASS;
                end

                TOP_COL_PASS: begin
                    // Step 1: Read 8 values from transpose buffer into col_input_buf
                    if (!col_buf_ready && !col_pass_feeding && !col_waiting_done) begin
                        if (tb_rd_valid) begin
                            col_input_buf[col_buf_wr_ptr[2:0]] <= tb_rd_data;
                            col_buf_wr_ptr <= col_buf_wr_ptr + 1;
                            if (col_buf_wr_ptr == 4'd7) begin
                                col_buf_ready <= 1'b1;
                            end
                        end
                    end

                    // Step 2: Start col DCT and feed 8 buffered values
                    if (col_buf_ready && !col_pass_started && !col_waiting_done && col_ready) begin
                        col_pass_started <= 1'b1;
                        col_feed_cnt     <= '0;
                        col_pass_feeding <= 1'b1;
                    end

                    if (col_pass_feeding) begin
                        col_feed_cnt <= col_feed_cnt + 1;
                        if (col_feed_cnt == 4'd7) begin
                            col_pass_feeding <= 1'b0;
                            col_waiting_done <= 1'b1;
                        end
                    end

                    // Step 3: Wait for col DCT done
                    if (col_done) begin
                        col_pass_started <= 1'b0;
                        col_waiting_done <= 1'b0;
                        col_buf_ready    <= 1'b0;
                        col_buf_wr_ptr   <= '0;
                        if (col_pass_cnt == 3'd7) begin
                            top_state <= TOP_QUANTIZE;
                        end else begin
                            col_pass_cnt <= col_pass_cnt + 1;
                        end
                    end
                end

                TOP_QUANTIZE: begin
                    // With SKIP_QUANTIZER=1, coefficients go directly to output buffer.
                    // With SKIP_QUANTIZER=0, wait for quantizer to process all 64 coefficients.
                    // In either case, the output buffer collects all 64 and raises block_ready.
                    if (block_ready)
                        top_state <= TOP_OUTPUT;
                end

                TOP_OUTPUT: begin
                    // Wait for output buffer to be fully read
                    if (block_done)
                        top_state <= TOP_IDLE;
                end

                default: top_state <= TOP_IDLE;
            endcase
        end
    end

    // =========================================================================
    // Datapath connections
    // =========================================================================

    // Pixel block buffer → row DCT: only request when actively feeding AND
    // the DCT engine is in LOAD state to avoid over-reading the PBB
    assign pbb_sample_req = (top_state == TOP_ROW_PASS) && row_pass_feeding;

    // Row DCT inputs
    assign row_start  = (top_state == TOP_ROW_PASS) && !row_pass_started && !row_pass_feeding && !row_waiting_done && row_ready;
    assign row_x_in   = pbb_sample;
    assign row_x_valid = (top_state == TOP_ROW_PASS) && pbb_sample_valid && row_pass_feeding;

    // Row DCT outputs → transpose buffer
    assign tb_wr_data  = row_y_out;
    assign tb_wr_valid = row_y_valid;

    // Transpose buffer read → column input buffer
    assign tb_rd_en = (top_state == TOP_COL_PASS) && !col_buf_ready && !col_pass_feeding && !col_waiting_done;

    // Column DCT inputs
    assign col_start  = (top_state == TOP_COL_PASS) && col_buf_ready && !col_pass_started && !col_waiting_done && col_ready;
    assign col_x_in   = col_input_buf[col_feed_cnt[2:0]];
    assign col_x_valid = (top_state == TOP_COL_PASS) && col_pass_feeding;

    // Column DCT outputs → quantizer (or bypass)
    assign q_coeff_in    = col_y_out;
    assign q_coeff_valid = col_y_valid;

    // Quantizer outputs → output buffer (or bypass)
    generate if (SKIP_QUANTIZER) begin : gen_skip_q
        assign ob_coeff_in    = col_y_out;
        assign ob_coeff_valid = col_y_valid;
    end else begin : gen_use_q
        assign ob_coeff_in    = q_quant_out;
        assign ob_coeff_valid = q_quant_valid;
    end endgenerate

endmodule
