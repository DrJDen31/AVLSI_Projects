% =========================================================================
% Advanced VLSI - Course Project
% Phase 1: Test Vector Generation
% 
% Objective: Generate input stimulus and expected output for Verilog testbench
% - Test 1: Impulse (verify coefficients)
% - Test 2: DC signal
% - Test 3: Passband tone
% - Test 4: Stopband tone
% - Test 5: Transition band tone
% - Test 6: Composite signal (random noise + tones)
% =========================================================================

clear; clc; close all;

%% 1. Load Quantized Coefficients
if exist('fir_coefficients_quantized.mat', 'file')
    load('fir_coefficients_quantized.mat');
else
    error('Run quantize_coeffs.m first to generate quantized coefficients.');
end

% Note: hardware filter uses best_hq (floating point equiv of quantized coeffs)
% for functional verification to check the exact bit-accurate math later.

%% 2. Setup Parameters
Fs = 1;                     % Normalized sampling frequency (fs = 1)
num_samples = 400;          % Length of each test signal
n = 0:(num_samples-1);

% Fractional format for input (Q1.input_frac)
input_frac_bits = input_bits - 1;
max_input_val = 2^(input_bits-1) - 1;

% Helper function to convert to hex for Verilog $readmemh
% Handles negative numbers using 2's complement
to_hex = @(x, bits) dec2hex(mod(round(x), 2^bits), ceil(bits/4));

%% 3. Generate Signals

% a) Impulse (x[n] = 1 at n=0, 0 otherwise)
% Scale to max positive value to see coefficients clearly
x_impulse = zeros(1, num_samples);
x_impulse(1) = 1.0; 

% b) DC Signal
x_dc = 0.5 * ones(1, num_samples); 

% c) Passband Tone (F = 0.1 * Fs/2) --> well within Fpass=0.2
f_pass = 0.1 / 2; % Normalized frequency is F / (Fs/2)
x_pass = 0.8 * sin(2*pi*f_pass*n);

% d) Stopband Tone (F = 0.5 * Fs/2) --> well beyond Fstop=0.23
f_stop = 0.5 / 2;
x_stop = 0.8 * sin(2*pi*f_stop*n);

% e) Transition Band Tone (F = 0.215 * Fs/2)
f_trans = 0.215 / 2;
x_trans = 0.8 * sin(2*pi*f_trans*n);

% f) Composite (Mix of pass, stop, and low-level noise)
x_noise = 0.1 * randn(1, num_samples);
x_comp = 0.4*sin(2*pi*f_pass*n) + 0.4*sin(2*pi*f_stop*n) + x_noise;
x_comp(x_comp > 1) = 1; x_comp(x_comp < -1) = -1; % Clip if necessary

% Combine all tests end-to-end with padding
padding = zeros(1, N + 50); % Padding to clear pipeline between tests
x_full = [x_impulse, padding, x_dc, padding, x_pass, padding, x_stop, padding, ...
          x_trans, padding, x_comp, padding];

% Quantize input signal to N bits
x_quant = round(x_full * max_input_val);

% Due to rounding, ensure we don't exceed max possible value
x_quant(x_quant > max_input_val) = max_input_val;
x_quant(x_quant < -max_input_val-1) = -max_input_val-1; % Assuming 2's comp min

%% 4. Generate Expected Golden Outputs
% The Verilog filter will compute SUM(x_int * h_int)
% x_int is Q(input_bits)
% h_int is Q(coeff_bits)
% Output accumulator is exact SUM, no truncation yet

% We compute the exact integer convolution
y_golden_int = conv(x_quant, hq_int);

%% 5. Write Verilog Readmemh Hex Files
tb_dir = '../tb/test_vectors';
if ~exist(tb_dir, 'dir')
    mkdir(tb_dir);
end

% Write Input
f_in = fopen(fullfile(tb_dir, 'input_stimulus.hex'), 'w');
for i = 1:length(x_quant)
    fprintf(f_in, '%s\n', to_hex(x_quant(i), input_bits));
end
fclose(f_in);

% Write Golden Output (Accumulator width)
f_out = fopen(fullfile(tb_dir, 'golden_output.hex'), 'w');
for i = 1:length(y_golden_int)
    fprintf(f_out, '%s\n', to_hex(y_golden_int(i), acc_bits));
end
fclose(f_out);

fprintf('Generated %d test samples.\n', length(x_quant));
fprintf('Written to %s/input_stimulus.hex\n', tb_dir);
fprintf('Written to %s/golden_output.hex\n', tb_dir);

%% 6. Plot the Test Signals
figure('Name', 'Test Vectors', 'Position', [200, 200, 900, 600]);

subplot(2,1,1);
plot(x_full);
title('Input Stimulus (x\_full)');
xlabel('Sample Number');
ylabel('Amplitude');
grid on;

subplot(2,1,2);
plot(y_golden_int);
title('Expected Golden Output (y\_golden\_int)');
xlabel('Sample Number');
ylabel('Accumulator Value');
grid on;

%% 7. Document the test boundaries for Verilog TB
f_meta = fopen(fullfile(tb_dir, 'test_metadata.txt'), 'w');
fprintf(f_meta, 'NUM_SAMPLES = %d\n', length(x_quant));
fprintf(f_meta, 'IMPULSE_START = 1\n');
fprintf(f_meta, 'DC_START = %d\n', length(x_impulse) + length(padding) + 1);
fprintf(f_meta, 'PASSBAND_START = %d\n', length(x_impulse) + length(padding)*2 + length(x_dc) + 1);
fprintf(f_meta, 'STOPBAND_START = %d\n', length(x_impulse) + length(padding)*3 + length(x_dc) + length(x_pass) + 1);
fclose(f_meta);
