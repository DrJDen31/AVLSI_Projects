// mac_unit.sv - signed multiply-accumulate
module mac_unit #(
    parameter int DATA_WIDTH  = 16,
    parameter int COEFF_WIDTH = 16,
    parameter int ACCUM_WIDTH = 32
) (
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    clr,        // synchronous accumulator clear
    input  logic                    en,         // load and accumulate this cycle
    input  logic signed [DATA_WIDTH-1:0]  data_in,
    input  logic signed [COEFF_WIDTH-1:0] coeff_in,
    output logic signed [ACCUM_WIDTH-1:0] accum_out
);

    logic signed [DATA_WIDTH+COEFF_WIDTH-1:0] product;
    assign product = data_in * coeff_in;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            accum_out <= '0;
        else if (clr)
            accum_out <= '0;
        else if (en)
            accum_out <= accum_out + ACCUM_WIDTH'(product);
    end

endmodule
