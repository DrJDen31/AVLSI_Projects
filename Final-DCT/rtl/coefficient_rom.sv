// coefficient_rom.sv - Q2.14 DCT cosine coefficient ROM (64 entries, synchronous read)
// Address: {k[2:0], n[2:0]} where k=DCT freq index, n=sample index
// Values: round(alpha_k * cos(pi*(2n+1)*k/16) * 2^14)
//   alpha_0 = sqrt(1/8), alpha_k = 0.5 for k=1..7
module coefficient_rom (
    input  logic                   clk,
    input  logic [5:0]             addr,     // {k[2:0], n[2:0]}
    output logic signed [15:0]     data_out
);

    logic signed [15:0] rom_val;

    always_comb begin
        case(addr)
            // k=0: all 5793
            6'd0, 6'd1, 6'd2, 6'd3, 6'd4, 6'd5, 6'd6, 6'd7: rom_val = 16'sh16A1;
            
            // k=1: 8035 6812 4552 1598 -1598 -4552 -6812 -8035
            6'd8:  rom_val = 16'sh1F63; 6'd9:  rom_val = 16'sh1A9C; 6'd10: rom_val = 16'sh11C8; 6'd11: rom_val = 16'sh063E;
            6'd12: rom_val = 16'shF9C2; 6'd13: rom_val = 16'shEE38; 6'd14: rom_val = 16'shE564; 6'd15: rom_val = 16'shE09D;
            
            // k=2: 7568 3135 -3135 -7568 -7568 -3135 3135 7568
            6'd16: rom_val = 16'sh1D90; 6'd17: rom_val = 16'sh0C3F; 6'd18: rom_val = 16'shF3C1; 6'd19: rom_val = 16'shE270;
            6'd20: rom_val = 16'shE270; 6'd21: rom_val = 16'shF3C1; 6'd22: rom_val = 16'sh0C3F; 6'd23: rom_val = 16'sh1D90;
            
            // k=3: 6812 -1598 -8035 -4552 4552 8035 1598 -6812
            6'd24: rom_val = 16'sh1A9C; 6'd25: rom_val = 16'shF9C2; 6'd26: rom_val = 16'shE09D; 6'd27: rom_val = 16'shEE38;
            6'd28: rom_val = 16'sh11C8; 6'd29: rom_val = 16'sh1F63; 6'd30: rom_val = 16'sh063E; 6'd31: rom_val = 16'shE564;
            
            // k=4: 5793 -5793 -5793 5793 5793 -5793 -5793 5793
            6'd32, 6'd35, 6'd36, 6'd39: rom_val = 16'sh16A1;
            6'd33, 6'd34, 6'd37, 6'd38: rom_val = 16'shE95F;
            
            // k=5: 4552 -8035 1598 6812 -6812 -1598 8035 -4552
            6'd40: rom_val = 16'sh11C8; 6'd41: rom_val = 16'shE09D; 6'd42: rom_val = 16'sh063E; 6'd43: rom_val = 16'sh1A9C;
            6'd44: rom_val = 16'shE564; 6'd45: rom_val = 16'shF9C2; 6'd46: rom_val = 16'sh1F63; 6'd47: rom_val = 16'shEE38;
            
            // k=6: 3135 -7568 7568 -3135 -3135 7568 -7568 3135
            6'd48: rom_val = 16'sh0C3F; 6'd49: rom_val = 16'shE270; 6'd50: rom_val = 16'sh1D90; 6'd51: rom_val = 16'shF3C1;
            6'd52: rom_val = 16'shF3C1; 6'd53: rom_val = 16'sh1D90; 6'd54: rom_val = 16'shE270; 6'd55: rom_val = 16'sh0C3F;
            
            // k=7: 1598 -4552 6812 -8035 8035 -6812 4552 -1598
            6'd56: rom_val = 16'sh063E; 6'd57: rom_val = 16'shEE38; 6'd58: rom_val = 16'sh1A9C; 6'd59: rom_val = 16'shE09D;
            6'd60: rom_val = 16'sh1F63; 6'd61: rom_val = 16'shE564; 6'd62: rom_val = 16'sh11C8; 6'd63: rom_val = 16'shF9C2;
            
            default: rom_val = 16'sh0000;
        endcase
    end

    always_ff @(posedge clk) begin
        data_out <= rom_val;
    end

endmodule
