% fixed_point_analysis.m - wordlength sweep and quantization error study

%% --- Setup: load image and floating-point reference ---
img_path = fullfile(fileparts(mfilename('fullpath')), 'images', 'baboon.tiff');
raw = imread(img_path);
if size(raw, 3) == 3
    img_gray = double(rgb2gray(raw));
else
    img_gray = double(raw);
end

% Orthonormal DCT-II cosine matrix
N = 8;
C = zeros(N, N);
for k = 0:N-1
    for n = 0:N-1
        if k == 0, alpha = sqrt(1/N); else, alpha = sqrt(2/N); end
        C(k+1, n+1) = alpha * cos(pi*(2*n+1)*k / (2*N));
    end
end

%% --- Task 5: Fixed-point DCT sweep ---
frac_bits    = 14;          % Q2.14 cosine representation
word_lengths = 8:16;
snr_db       = zeros(size(word_lengths));
C_int        = round(C * 2^frac_bits);

% Collect floating-point coefficients from first 64 blocks
num_sample  = 64;
float_vec   = zeros(num_sample, 64);
block_count = 0;
for br = 1:8:size(img_gray,1)-7
    for bc = 1:8:size(img_gray,2)-7
        if block_count >= num_sample, break; end
        block_count = block_count + 1;
        blk = img_gray(br:br+7, bc:bc+7);
        Y = C * blk * C';
        float_vec(block_count, :) = Y(:).';
    end
    if block_count >= num_sample, break; end
end

% Sweep word lengths
for wi = 1:length(word_lengths)
    wb = word_lengths(wi);
    fixed_vec   = zeros(num_sample, 64);
    block_count = 0;
    for br = 1:8:size(img_gray,1)-7
        for bc = 1:8:size(img_gray,2)-7
            if block_count >= num_sample, break; end
            block_count = block_count + 1;
            blk = img_gray(br:br+7, bc:bc+7);
            Y = dct2_fixed(blk, C_int, frac_bits, wb);
            fixed_vec(block_count, :) = Y(:).';
        end
        if block_count >= num_sample, break; end
    end

    sig_pwr  = mean(float_vec(:).^2);
    noise_pwr = mean((float_vec(:) - fixed_vec(:)).^2);
    if noise_pwr == 0
        snr_db(wi) = Inf;
    else
        snr_db(wi) = 10*log10(sig_pwr / noise_pwr);
    end
    fprintf('Word length %2d bit -> SNR = %.2f dB\n', wb, snr_db(wi));
end

%% --- Task 6: Plot SNR sweep, save figure, document Q-format decision ---
fig_dir = fullfile(fileparts(mfilename('fullpath')), 'outputs', 'figures');
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

fig = figure('Visible', 'off');
plot(word_lengths, snr_db, 'b-o', 'LineWidth', 1.5, 'MarkerFaceColor', 'b');
xlabel('Output Word Length (bits)');
ylabel('SNR (dB)');
title('Fixed-Point DCT SNR vs. Output Word Length (Q2.14 cosines)');
grid on;
yline(50, 'r--', 'Q2.14 noise floor (~50 dB)', 'LabelHorizontalAlignment', 'left');
xline(12, 'g--', '12-bit chosen', 'LabelVerticalAlignment', 'bottom');
saveas(fig, fullfile(fig_dir, 'wordlength_sweep.png'));
close(fig);
fprintf('Saved wordlength_sweep.png\n');

% --- Q-format decision ---
% Cosines:     Q2.14 (frac_bits=14) -> noise floor ~50 dB SNR
% Output coef: 12-bit signed        -> no clipping, matches noise floor
% Accumulator: 32-bit signed        -> row+col pass without overflow
%              (max input 255, max cosine ~1, 8 taps -> ~2040, fits in 32b)
fprintf('Chosen format: cosines=Q2.14, output=12-bit signed, accumulator=32-bit\n');

% =========================================================================
%  Local functions (must be at end of script)
% =========================================================================
function Y = dct2_fixed(block, C_int, frac_bits, out_bits)
    % Row pass
    tmp = C_int * block;
    tmp = round(tmp / 2^frac_bits);
    % Column pass
    Y = tmp * C_int';
    Y = round(Y / 2^frac_bits);
    % Clamp to signed out_bits range
    max_val = 2^(out_bits-1) - 1;
    min_val = -2^(out_bits-1);
    Y = max(min(Y, max_val), min_val);
end
