% =========================================================================
% Advanced VLSI - Course Project
% Phase 1: Coefficient Quantization
% 
% Objective: Quantize the ideal FIR filter coefficients
% - Compare ideal vs quantized frequency responses
% - Find minimum fractional bits to maintain 80dB stopband attenuation
% - Prevent overflow in accumulator
% =========================================================================

clear; clc; close all;

%% 1. Load Ideal Filter Design
if exist('fir_coefficients_ideal.mat', 'file')
    load('fir_coefficients_ideal.mat');
else
    error('Run fir_design.m first to generate ideal coefficients.');
end

%% 2. Fixed-Point Quantization Function
% Helper to quantize coefficients to Q(integer_bits).(fractional_bits) format
% Assumes signed numbers (1 sign bit)
quantize = @(x, int_bits, frac_bits) round(x .* (2^frac_bits)) ./ (2^frac_bits);

%% 3. Iterate Fractional Bits to Meet Spec
% We need to maintain the Astop (80dB) requirement after quantization
target_attenuation = Astop;
min_fractional_bits = 8;
max_fractional_bits = 24;

% Integer bits required for coefficients.
% Since coefficients are usually between -1 and 1, we need 0 integer bits
% + 1 sign bit.
int_bits = 0; % purely fractional, + 1 sign bit

fprintf('--- Quantization Search ---\n');
fprintf('Target Stopband Attenuation: > %.2f dB\n', target_attenuation);

best_frac_bits = 0;
best_hq = [];
found_spec = false;

for f_bits = min_fractional_bits:max_fractional_bits
    % Quantize
    hq = quantize(h_ideal, int_bits, f_bits);
    
    % Analyze magnitude response
    [Hq, Wq] = freqz(hq, 1, 1024);
    
    % Find minimum attenuation in the stopband
    stop_idx = (Wq/pi >= Fstop);
    Hq_stop = 20*log10(abs(Hq(stop_idx)));
    actual_attenuation = -max(Hq_stop);
    
    fprintf('Testing %2d fractional bits: Attenuation = %6.2f dB\n', f_bits, actual_attenuation);
    
    if actual_attenuation >= target_attenuation && ~found_spec
        best_frac_bits = f_bits;
        best_hq = hq;
        found_spec = true;
        fprintf('>>> SPEC MET with %d fractional bits! <<<\n', best_frac_bits);
        % Continue loop just to show data, but we found our minimum
    end
end

if ~found_spec
    warning('Could not meet stopband spec even with %d fractional bits.', max_fractional_bits);
    best_frac_bits = max_fractional_bits;
    best_hq = quantize(h_ideal, int_bits, best_frac_bits);
end

%% 4. Data Width and Overflow Analysis
% Given input data width (e.g. 16 bits: 1 sign, 15 fraction)
input_bits = 16;
input_sign_bits = 1;
input_frac_bits = input_bits - input_sign_bits;

% Coefficient width
coeff_sign_bits = 1;
coeff_frac_bits = best_frac_bits;
coeff_bits = coeff_sign_bits + int_bits + coeff_frac_bits;

% Max growth during convolution
% Worst case output = SUM(|coeff|) * max_input
sum_abs_hq = sum(abs(best_hq));
guard_bits = ceil(log2(sum_abs_hq));

% Multiplier output width
mult_bits = input_bits + coeff_bits;
mult_frac_bits = input_frac_bits + coeff_frac_bits;

% Accumulator width to guarantee no overflow
acc_bits = mult_bits + ceil(log2(N)) + guard_bits;
acc_frac_bits = mult_frac_bits;

fprintf('\n--- Hardware Datapath Widths ---\n');
fprintf('Input Width:       %2d bits (Q%d.%d)\n', input_bits, input_sign_bits-1, input_frac_bits);
fprintf('Coefficient Width: %2d bits (Q%d.%d)\n', coeff_bits, coeff_sign_bits-1, coeff_frac_bits);
fprintf('Multiplier Output: %2d bits (Q%d.%d)\n', mult_bits, mult_bits-mult_frac_bits-1, mult_frac_bits);
fprintf('Guard Bits:        %2d bits\n', guard_bits);
fprintf('Accumulator Width: %2d bits (Q%d.%d)\n', acc_bits, acc_bits-acc_frac_bits-1, acc_frac_bits);
fprintf('Output Width:      %2d bits (truncated/rounded from accumulator)\n', input_bits);

%% 5. Plot Ideal vs Quantized Frequency Response
[H_ideal, W] = freqz(h_ideal, 1, 1024);
[H_quant, W_quant] = freqz(best_hq, 1, 1024);

figure('Name', 'Quantization Effects', 'Position', [150, 150, 800, 500]);
plot(W/pi, 20*log10(abs(H_ideal)), 'b-', 'LineWidth', 1.5);
hold on; grid on;
plot(W_quant/pi, 20*log10(abs(H_quant)), 'r--', 'LineWidth', 1.5);

yline(-Astop, 'k:', 'Stopband Spec (-80dB)');
xline(Fstop, 'k:');

title(sprintf('FIR Filter Response: Ideal vs %d-bit Quantized Coeffs', coeff_bits));
xlabel('Normalized Frequency (\times\pi rad/sample)');
ylabel('Magnitude (dB)');
axis([0 1 -120 10]);
legend('Ideal (Double Precision)', sprintf('Quantized (%d-bit)', coeff_bits), 'Location', 'SouthWest');

%% 6. Convert Quantized Coefficients to Integer Format for Verilog
% Multiply by 2^frac_bits to get raw integer values
hq_int = round(best_hq .* (2^best_frac_bits));

% Save for test vector generation
save('fir_coefficients_quantized.mat', 'hq_int', 'best_hq', 'coeff_bits', 'best_frac_bits', 'N', 'input_bits', 'acc_bits');
fprintf('\nSaved quantized coefficients to fir_coefficients_quantized.mat\n');

%% 7. Generate Verilog ROM / Parameter File
% Write coefficients out to a Verilog syntax file
% It's often easiest to use a pure package or a module with a case statement/ROM
fout = fopen('../rtl/coeff_pkg.sv', 'w');
fprintf(fout, '// Automatically generated by quantize_coeffs.m\n');
fprintf(fout, 'package coeff_pkg;\n\n');
fprintf(fout, '  localparam int N_TAPS   = %d;\n', N);
fprintf(fout, '  localparam int COEFF_W  = %d;\n', coeff_bits);
fprintf(fout, '  localparam int DATA_W   = %d;\n', input_bits);
fprintf(fout, '  localparam int ACC_W    = %d;\n\n', acc_bits);
fprintf(fout, '  // %d-bit fractional format (Q1.%d)\n', coeff_bits, best_frac_bits);
fprintf(fout, '  localparam signed [COEFF_W-1:0] COEFFS [0:N_TAPS-1] = ''{\n');

for i = 1:N
    % Convert negative numbers to 2's complement hex for cleaner representation
    % Handle MATLAB's lack of clean n-bit 2's complement native hex formatting
    val = hq_int(i);
    if val < 0
        val = val + 2^coeff_bits;
    end
    
    hex_width = ceil(coeff_bits / 4);
    format_str = sprintf('    %d''h%%0%dX', coeff_bits, hex_width);
    
    if i < N
        fprintf(fout, [format_str, ',\n'], val);
    else
        fprintf(fout, [format_str, '\n  };\n'], val);
    end
end

fprintf(fout, '\nendpackage : coeff_pkg\n');
fclose(fout);
fprintf('Generated SystemVerilog coefficient package at ../rtl/coeff_pkg.sv\n');
