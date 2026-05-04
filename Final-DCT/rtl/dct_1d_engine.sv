// dct_1d_engine.sv - parameterized 1D DCT compute engine
// D1 (PARALLEL=0, PIPELINE_STAGES=1): sequential single-MAC, 8 cycles per coefficient
// D2 (PARALLEL=0, PIPELINE_STAGES=4): pipelined single-MAC path
// D3 (PARALLEL=1, PIPELINE_STAGES=1): 8 parallel MACs, full row in 8 cycles
// D4 (PARALLEL=1, PIPELINE_STAGES=4): 8 parallel MACs + pipeline registers
module dct_1d_engine #(
    parameter int DATA_WIDTH      = 16,
    parameter int COEFF_WIDTH     = 16,
    parameter int ACCUM_WIDTH     = 32,
    parameter int FRAC_BITS       = 14,
    parameter int PARALLEL        = 0,
    parameter int PIPELINE_STAGES = 1
) (
    input  logic                           clk,
    input  logic                           rst_n,
    input  logic                           start,
    input  logic signed [DATA_WIDTH-1:0]   x_in,
    input  logic                           x_valid,
    output logic signed [DATA_WIDTH-1:0]   y_out,
    output logic                           y_valid,
    output logic                           done,
    output logic                           ready
);

    // =========================================================================
    // D1: Baseline sequential implementation
    // =========================================================================
    generate if (PARALLEL == 0 && PIPELINE_STAGES == 1) begin : gen_d1

        typedef enum logic [1:0] {
            S_IDLE    = 2'd0,
            S_LOAD    = 2'd1,
            S_COMPUTE = 2'd2,
            S_OUTPUT  = 2'd3
        } state_t;
        state_t state;

        // Input register file
        logic signed [DATA_WIDTH-1:0] x_reg [0:7];
        logic [2:0] load_cnt;

        // Compute indices
        logic [2:0] k_idx;          // current output coefficient (0..7)
        logic [3:0] phase;          // 0=clear, 1..8=MAC n=0..7, 9=capture output

        // ROM
        logic [5:0]         rom_addr;
        logic signed [15:0] rom_data;

        coefficient_rom u_rom (
            .clk      (clk),
            .addr     (rom_addr),
            .data_out (rom_data)
        );

        // MAC
        logic                           mac_clr, mac_en;
        logic signed [DATA_WIDTH-1:0]   mac_data;
        logic signed [COEFF_WIDTH-1:0]  mac_coeff;
        logic signed [ACCUM_WIDTH-1:0]  mac_accum;

        mac_unit #(
            .DATA_WIDTH  (DATA_WIDTH),
            .COEFF_WIDTH (COEFF_WIDTH),
            .ACCUM_WIDTH (ACCUM_WIDTH)
        ) u_mac (
            .clk       (clk),
            .rst_n     (rst_n),
            .clr       (mac_clr),
            .en        (mac_en),
            .data_in   (mac_data),
            .coeff_in  (mac_coeff),
            .accum_out (mac_accum)
        );

        // Pre-fetch ROM address
        logic [2:0] rom_n;
        always_comb begin
            if (state == S_COMPUTE) begin
                case (phase)
                    4'd0:    rom_n = 3'd0;
                    default: rom_n = phase[2:0];
                endcase
            end else begin
                rom_n = 3'd0;
            end
        end
        assign rom_addr = {k_idx, rom_n};

        // MAC control — explicit 3-bit index to avoid width-promotion bug
        assign mac_clr   = (state == S_COMPUTE) && (phase == 4'd0);
        assign mac_en    = (state == S_COMPUTE) && (phase >= 4'd1) && (phase <= 4'd8);
        wire [2:0] mac_idx = phase[2:0] - 3'd1;
        assign mac_data  = (mac_en) ? x_reg[mac_idx] : '0;
        assign mac_coeff = rom_data;

        // Output capture
        logic signed [DATA_WIDTH-1:0] y_out_r;
        logic y_valid_r;
        logic done_r;
        logic [2:0] out_cnt;

        always_ff @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                state    <= S_IDLE;
                load_cnt <= '0;
                k_idx    <= '0;
                phase    <= '0;
                y_valid_r <= 1'b0;
                done_r    <= 1'b0;
                out_cnt   <= '0;
                y_out_r   <= '0;
                for (int i = 0; i < 8; i++)
                    x_reg[i] <= '0;
            end else begin
                y_valid_r <= 1'b0;
                done_r    <= 1'b0;

                case (state)
                    S_IDLE: begin
                        load_cnt <= '0;
                        k_idx    <= '0;
                        phase    <= '0;
                        out_cnt  <= '0;
                        if (start)
                            state <= S_LOAD;
                    end

                    S_LOAD: begin
                        if (x_valid) begin
                            x_reg[load_cnt] <= x_in;
                            if (load_cnt == 3'd7) begin
                                state <= S_COMPUTE;
                                phase <= 4'd0;
                                k_idx <= 3'd0;
                            end
                            load_cnt <= load_cnt + 1;
                        end
                    end

                    S_COMPUTE: begin
                        if (phase == 4'd9) begin
                            // Capture output: accumulator has final value
                            y_out_r   <= DATA_WIDTH'((mac_accum + (1 <<< (FRAC_BITS-1))) >>> FRAC_BITS);
                            y_valid_r <= 1'b1;
                            out_cnt   <= out_cnt + 1;

                            if (k_idx == 3'd7) begin
                                done_r <= 1'b1;
                                state  <= S_IDLE;
                            end else begin
                                k_idx <= k_idx + 1;
                                phase <= 4'd0;
                            end
                        end else begin
                            phase <= phase + 1;
                        end
                    end

                    default: state <= S_IDLE;
                endcase
            end
        end

        assign y_out   = y_out_r;
        assign y_valid = y_valid_r;
        assign done    = done_r;
        assign ready   = (state == S_IDLE);

    // =========================================================================
    // D2: Pipelined (PIPELINE_STAGES=4, PARALLEL=0)
    // k-outer/n-inner iteration. Single local accumulator per k.
    // 4-stage pipeline: ROM-address → ROM-data+operand-latch → Multiply → Accumulate
    // For each k: issue 8 ROM reads (n=0..7), drain pipeline (3 extra cycles),
    // then emit the rounded result.
    // =========================================================================
    end else if (PARALLEL == 0 && PIPELINE_STAGES == 4) begin : gen_d2

        typedef enum logic [2:0] {
            S_IDLE    = 3'd0,
            S_LOAD    = 3'd1,
            S_COMPUTE = 3'd2,
            S_DRAIN   = 3'd3,
            S_EMIT    = 3'd4
        } state_t;
        state_t state;

        // Input register file
        logic signed [DATA_WIDTH-1:0] x_reg [0:7];
        logic [2:0] load_cnt;

        // Iteration indices
        logic [2:0] k_idx;     // current output coefficient (0..7)
        logic [3:0] n_cnt;     // ROM address issue counter (0..8; 0=first issue, 8=done)
        logic [2:0] drain_cnt; // pipeline drain counter
        logic [2:0] out_cnt;   // total outputs emitted

        // ROM
        logic [5:0]         rom_addr;
        logic signed [15:0] rom_data;

        coefficient_rom u_rom (
            .clk      (clk),
            .addr     (rom_addr),
            .data_out (rom_data)
        );

        // ROM address: {k_idx, n_cnt[2:0]}
        assign rom_addr = {k_idx, n_cnt[2:0]};

        // Pipeline registers
        // Stage 2: ROM data + x_reg value latched (1 cycle after ROM address)
        logic signed [DATA_WIDTH-1:0]  p2_x;
        logic signed [COEFF_WIDTH-1:0] p2_c;
        logic                          p2_valid;

        // Stage 3: multiply result
        logic signed [ACCUM_WIDTH-1:0] p3_prod;
        logic                          p3_valid;

        // Local accumulator (replaces mac_unit for D2)
        logic signed [ACCUM_WIDTH-1:0] local_accum;

        // Output registers
        logic signed [DATA_WIDTH-1:0] y_out_r;
        logic y_valid_r;
        logic done_r;

        always_ff @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                state       <= S_IDLE;
                load_cnt    <= '0;
                k_idx       <= '0;
                n_cnt       <= '0;
                drain_cnt   <= '0;
                out_cnt     <= '0;
                y_valid_r   <= 1'b0;
                done_r      <= 1'b0;
                y_out_r     <= '0;
                p2_x        <= '0;
                p2_c        <= '0;
                p2_valid    <= 1'b0;
                p3_prod     <= '0;
                p3_valid    <= 1'b0;
                local_accum <= '0;
                for (int i = 0; i < 8; i++)
                    x_reg[i] <= '0;
            end else begin
                y_valid_r <= 1'b0;
                done_r    <= 1'b0;

                // === Pipeline Stage 2: latch ROM data + x sample ===
                // ROM data is available 1 cycle after address is issued.
                // At n_cnt=0, we issue the first address. ROM data arrives when n_cnt=1.
                // So p2 captures valid data when n_cnt was >= 1 in the PREVIOUS cycle.
                // We use a 'feed_valid' signal delayed by one cycle to track this.
                if (state == S_COMPUTE && n_cnt >= 4'd1 && n_cnt <= 4'd8) begin
                    // n_cnt is already incremented, so n_cnt-1 was the address we issued
                    // last cycle. ROM data for that address is now available.
                    p2_x     <= x_reg[n_cnt[2:0] - 3'd1];
                    p2_c     <= rom_data;
                    p2_valid <= 1'b1;
                end else begin
                    p2_valid <= 1'b0;
                end

                // === Pipeline Stage 3: multiply ===
                p3_prod  <= ACCUM_WIDTH'($signed(p2_x) * $signed(p2_c));
                p3_valid <= p2_valid;

                // === Pipeline Stage 4: accumulate ===
                if (state == S_EMIT) begin
                    // Clear accumulator after emitting
                    local_accum <= '0;
                end else if (p3_valid) begin
                    local_accum <= local_accum + p3_prod;
                end

                // === FSM ===
                case (state)
                    S_IDLE: begin
                        load_cnt <= '0;
                        k_idx    <= '0;
                        n_cnt    <= '0;
                        out_cnt  <= '0;
                        if (start)
                            state <= S_LOAD;
                    end

                    S_LOAD: begin
                        if (x_valid) begin
                            x_reg[load_cnt] <= x_in;
                            if (load_cnt == 3'd7) begin
                                state <= S_COMPUTE;
                                n_cnt <= 4'd0;
                                k_idx <= 3'd0;
                                local_accum <= '0;
                            end
                            load_cnt <= load_cnt + 1;
                        end
                    end

                    S_COMPUTE: begin
                        // Issue ROM addresses for n=0..7
                        if (n_cnt == 4'd8) begin
                            state     <= S_DRAIN;
                            drain_cnt <= '0;
                        end else begin
                            n_cnt <= n_cnt + 1;
                        end
                    end

                    S_DRAIN: begin
                        // Wait for pipeline to drain (need 3 more cycles for stages 2,3,4)
                        if (drain_cnt == 3'd2) begin
                            state <= S_EMIT;
                        end
                        drain_cnt <= drain_cnt + 1;
                    end

                    S_EMIT: begin
                        // Emit rounded result from local accumulator
                        y_out_r   <= DATA_WIDTH'((local_accum + (1 <<< (FRAC_BITS-1))) >>> FRAC_BITS);
                        y_valid_r <= 1'b1;
                        out_cnt   <= out_cnt + 1;

                        if (k_idx == 3'd7) begin
                            done_r <= 1'b1;
                            state  <= S_IDLE;
                        end else begin
                            k_idx <= k_idx + 1;
                            n_cnt <= 4'd0;
                            state <= S_COMPUTE;
                            // local_accum cleared at top of else-if block
                        end
                    end

                    default: state <= S_IDLE;
                endcase
            end
        end

        assign y_out   = y_out_r;
        assign y_valid = y_valid_r;
        assign done    = done_r;
        assign ready   = (state == S_IDLE);

    // =========================================================================
    // D3: Parallel (PARALLEL=1, PIPELINE_STAGES=1)
    // 8 parallel MACs compute all 8 output coefficients simultaneously.
    // Compute phase: 10 cycles (clear + 8 MAC + latch).
    // Output phase:  8 cycles (serialize 8 rounded results).
    // Total per row: ~18 cycles vs D1's ~80 cycles.
    // =========================================================================
    end else if (PARALLEL == 1 && PIPELINE_STAGES == 1) begin : gen_d3

        typedef enum logic [1:0] {
            S_IDLE    = 2'd0,
            S_LOAD    = 2'd1,
            S_COMPUTE = 2'd2,
            S_OUTPUT  = 2'd3
        } state_t;
        state_t state;

        // Input register file
        logic signed [DATA_WIDTH-1:0] x_reg [0:7];
        logic [2:0] load_cnt;

        // Compute phase counter: 0=clear, 1..8=MAC n=0..7, 9=done
        logic [3:0] phase;

        // ---- 8 parallel ROMs: ROM[k] addressed by {k, n} ----
        logic [2:0] rom_n;
        logic signed [15:0] rom_data_par [0:7];

        genvar gk;
        for (gk = 0; gk < 8; gk++) begin : gen_rom
            wire [5:0] rom_addr_k = {gk[2:0], rom_n};
            coefficient_rom u_rom (
                .clk      (clk),
                .addr     (rom_addr_k),
                .data_out (rom_data_par[gk])
            );
        end

        // Pre-fetch ROM address (same logic as D1)
        always_comb begin
            if (state == S_COMPUTE) begin
                case (phase)
                    4'd0:    rom_n = 3'd0;
                    default: rom_n = phase[2:0];
                endcase
            end else begin
                rom_n = 3'd0;
            end
        end

        // ---- 8 parallel MACs ----
        logic                           mac_clr, mac_en;
        logic signed [DATA_WIDTH-1:0]   mac_data;
        logic signed [ACCUM_WIDTH-1:0]  mac_accum [0:7];

        assign mac_clr  = (state == S_COMPUTE) && (phase == 4'd0);
        assign mac_en   = (state == S_COMPUTE) && (phase >= 4'd1) && (phase <= 4'd8);
        wire [2:0] mac_idx = phase[2:0] - 3'd1;
        assign mac_data = (mac_en) ? x_reg[mac_idx] : '0;

        for (gk = 0; gk < 8; gk++) begin : gen_mac
            mac_unit #(
                .DATA_WIDTH  (DATA_WIDTH),
                .COEFF_WIDTH (COEFF_WIDTH),
                .ACCUM_WIDTH (ACCUM_WIDTH)
            ) u_mac (
                .clk       (clk),
                .rst_n     (rst_n),
                .clr       (mac_clr),
                .en        (mac_en),
                .data_in   (mac_data),
                .coeff_in  (rom_data_par[gk]),
                .accum_out (mac_accum[gk])
            );
        end

        // ---- Output serialization ----
        logic signed [DATA_WIDTH-1:0] y_out_r;
        logic y_valid_r;
        logic done_r;
        logic [2:0] out_idx;

        always_ff @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                state     <= S_IDLE;
                load_cnt  <= '0;
                phase     <= '0;
                y_valid_r <= 1'b0;
                done_r    <= 1'b0;
                out_idx   <= '0;
                y_out_r   <= '0;
                for (int i = 0; i < 8; i++)
                    x_reg[i] <= '0;
            end else begin
                y_valid_r <= 1'b0;
                done_r    <= 1'b0;

                case (state)
                    S_IDLE: begin
                        load_cnt <= '0;
                        phase    <= '0;
                        out_idx  <= '0;
                        if (start)
                            state <= S_LOAD;
                    end

                    S_LOAD: begin
                        if (x_valid) begin
                            x_reg[load_cnt] <= x_in;
                            if (load_cnt == 3'd7) begin
                                state <= S_COMPUTE;
                                phase <= 4'd0;
                            end
                            load_cnt <= load_cnt + 1;
                        end
                    end

                    S_COMPUTE: begin
                        if (phase == 4'd9) begin
                            // All 8 accumulators hold final sums — serialize
                            state   <= S_OUTPUT;
                            out_idx <= 3'd0;
                        end else begin
                            phase <= phase + 1;
                        end
                    end

                    S_OUTPUT: begin
                        // Emit one rounded coefficient per cycle
                        y_out_r   <= DATA_WIDTH'((mac_accum[out_idx] + (1 <<< (FRAC_BITS-1))) >>> FRAC_BITS);
                        y_valid_r <= 1'b1;

                        if (out_idx == 3'd7) begin
                            done_r <= 1'b1;
                            state  <= S_IDLE;
                        end else begin
                            out_idx <= out_idx + 1;
                        end
                    end

                    default: state <= S_IDLE;
                endcase
            end
        end

        assign y_out   = y_out_r;
        assign y_valid = y_valid_r;
        assign done    = done_r;
        assign ready   = (state == S_IDLE);

    // =========================================================================
    // D4: Pipelined + Parallel (PARALLEL=1, PIPELINE_STAGES=4)
    // =========================================================================
    end else if (PARALLEL == 1 && PIPELINE_STAGES == 4) begin : gen_d4

        typedef enum logic [2:0] {
            S_IDLE    = 3'd0,
            S_LOAD    = 3'd1,
            S_COMPUTE = 3'd2,
            S_DRAIN   = 3'd3,
            S_OUTPUT  = 3'd4
        } state_t;
        state_t state;

        // Input register file
        logic signed [DATA_WIDTH-1:0] x_reg [0:7];
        logic [2:0] load_cnt;

        // Iteration indices
        logic [3:0] n_cnt;     // ROM address issue counter
        logic [2:0] drain_cnt; // pipeline drain counter
        logic [2:0] out_idx;   // output serialization counter

        // ---- 8 parallel ROMs ----
        logic signed [15:0] rom_data_par [0:7];
        genvar gk;
        for (gk = 0; gk < 8; gk++) begin : gen_rom
            wire [5:0] rom_addr_k = {gk[2:0], n_cnt[2:0]};
            coefficient_rom u_rom (
                .clk      (clk),
                .addr     (rom_addr_k),
                .data_out (rom_data_par[gk])
            );
        end

        // Pipeline registers
        // Stage 2: ROM data + x_reg value latched
        logic signed [DATA_WIDTH-1:0]  p2_x;
        logic signed [COEFF_WIDTH-1:0] p2_c [0:7];
        logic                          p2_valid;

        // Stage 3: multiply result
        logic signed [ACCUM_WIDTH-1:0] p3_prod [0:7];
        logic                          p3_valid;

        // Stage 4: local accumulators
        logic signed [ACCUM_WIDTH-1:0] local_accum [0:7];

        // Output registers
        logic signed [DATA_WIDTH-1:0] y_out_r;
        logic y_valid_r;
        logic done_r;

        always_ff @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                state       <= S_IDLE;
                load_cnt    <= '0;
                n_cnt       <= '0;
                drain_cnt   <= '0;
                out_idx     <= '0;
                y_valid_r   <= 1'b0;
                done_r      <= 1'b0;
                y_out_r     <= '0;
                p2_x        <= '0;
                p2_valid    <= 1'b0;
                p3_valid    <= 1'b0;
                for (int i = 0; i < 8; i++) begin
                    x_reg[i]       <= '0;
                    p2_c[i]        <= '0;
                    p3_prod[i]     <= '0;
                    local_accum[i] <= '0;
                end
            end else begin
                y_valid_r <= 1'b0;
                done_r    <= 1'b0;

                // === Pipeline Stage 2: latch ROM data + x sample ===
                if (state == S_COMPUTE && n_cnt >= 4'd1 && n_cnt <= 4'd8) begin
                    p2_x <= x_reg[n_cnt[2:0] - 3'd1];
                    for (int k = 0; k < 8; k++) begin
                        p2_c[k] <= rom_data_par[k];
                    end
                    p2_valid <= 1'b1;
                end else begin
                    p2_valid <= 1'b0;
                end

                // === Pipeline Stage 3: multiply ===
                for (int k = 0; k < 8; k++) begin
                    p3_prod[k] <= ACCUM_WIDTH'($signed(p2_x) * $signed(p2_c[k]));
                end
                p3_valid <= p2_valid;

                // === Pipeline Stage 4: accumulate ===
                if (state == S_LOAD && x_valid && load_cnt == 3'd7) begin
                    for (int k = 0; k < 8; k++) begin
                        local_accum[k] <= '0;
                    end
                end else if (p3_valid) begin
                    for (int k = 0; k < 8; k++) begin
                        local_accum[k] <= local_accum[k] + p3_prod[k];
                    end
                end

                // === FSM ===
                case (state)
                    S_IDLE: begin
                        load_cnt <= '0;
                        n_cnt    <= '0;
                        out_idx  <= '0;
                        if (start)
                            state <= S_LOAD;
                    end

                    S_LOAD: begin
                        if (x_valid) begin
                            x_reg[load_cnt] <= x_in;
                            if (load_cnt == 3'd7) begin
                                state <= S_COMPUTE;
                                n_cnt <= 4'd0;
                                // local_accum is cleared above
                            end
                            load_cnt <= load_cnt + 1;
                        end
                    end

                    S_COMPUTE: begin
                        if (n_cnt == 4'd8) begin
                            state     <= S_DRAIN;
                            drain_cnt <= '0;
                        end else begin
                            n_cnt <= n_cnt + 1;
                        end
                    end

                    S_DRAIN: begin
                        if (drain_cnt == 3'd2) begin
                            state   <= S_OUTPUT;
                            out_idx <= 3'd0;
                        end
                        drain_cnt <= drain_cnt + 1;
                    end

                    S_OUTPUT: begin
                        // Emit one rounded coefficient per cycle
                        y_out_r   <= DATA_WIDTH'((local_accum[out_idx] + (1 <<< (FRAC_BITS-1))) >>> FRAC_BITS);
                        y_valid_r <= 1'b1;

                        if (out_idx == 3'd7) begin
                            done_r <= 1'b1;
                            state  <= S_IDLE;
                        end else begin
                            out_idx <= out_idx + 1;
                        end
                    end

                    default: state <= S_IDLE;
                endcase
            end
        end

        assign y_out   = y_out_r;
        assign y_valid = y_valid_r;
        assign done    = done_r;
        assign ready   = (state == S_IDLE);

    end endgenerate

endmodule
