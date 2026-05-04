% reconstruct_verify.m - IDCT reconstruction + PSNR verification

%% --- Setup ---
base_dir = fileparts(mfilename('fullpath'));
img_path = fullfile(base_dir, 'images', 'baboon.tiff');
raw = imread(img_path);
if size(raw, 3) == 3
    img_gray = double(rgb2gray(raw));
else
    img_gray = double(raw);
end
[rows, cols] = size(img_gray);

% Orthonormal DCT-II cosine matrix
N = 8;
C = zeros(N, N);
for k = 0:N-1
    for n = 0:N-1
        if k == 0, alpha = sqrt(1/N); else, alpha = sqrt(2/N); end
        C(k+1, n+1) = alpha * cos(pi*(2*n+1)*k / (2*N));
    end
end

% JPEG luminance Q-table at QF=70
Q_base = [
    16  11  10  16  24  40  51  61;
    12  12  14  19  26  58  60  55;
    14  13  16  24  40  57  69  56;
    14  17  22  29  51  87  80  62;
    18  22  37  56  68 109 103  77;
    24  35  55  64  81 104 113  92;
    49  64  78  87 103 121 120 101;
    72  92  95  98 112 100 103  99
];
qf = 70;
scale = 200 - 2*qf;
Q = max(min(floor((Q_base * scale + 50) / 100), 255), 1);

%% --- Task 12a: Read golden coefficients (placeholder for RTL output) ---
coeff_file = fullfile(base_dir, 'outputs', 'golden_coeffs.txt');
fid = fopen(coeff_file, 'r');
raw_data = textscan(fid, '%f');
fclose(fid);
all_coeffs = raw_data{1};
% golden_coeffs.txt: 4096 blocks x 8 rows, 8 values per row, blank line between blocks
% textscan gives us all floats in order; reshape into [4096 x 64]
all_coeffs = reshape(all_coeffs, 64, [])';  % [4096 x 64], row-major per block

%% --- Task 12b: Dequantize + IDCT, stitch blocks ---
recon = zeros(rows, cols);
block_idx = 0;
for br = 1:8:rows-7
    for bc = 1:8:cols-7
        block_idx = block_idx + 1;
        dct_blk  = reshape(all_coeffs(block_idx, :), 8, 8)';
        quant    = round(dct_blk ./ Q);
        dequant  = quant .* Q;
        recon_blk = C' * dequant * C;
        recon(br:br+7, bc:bc+7) = recon_blk;
    end
end
recon = max(min(recon, 255), 0);

%% --- Task 12c: Compute PSNR, save outputs ---
out_dir = fullfile(base_dir, 'outputs');
fig_dir = fullfile(out_dir, 'figures');
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

mse  = mean((img_gray(:) - recon(:)).^2);
psnr_val = 10*log10(255^2 / mse);
fprintf('PSNR (QF=%d, golden coeffs): %.2f dB\n', qf, psnr_val);

% Write psnr_result.txt
fid = fopen(fullfile(out_dir, 'psnr_result.txt'), 'w');
fprintf(fid, 'Source:      golden_coeffs.txt (floating-point DCT, QF=%d quantization)\n', qf);
fprintf(fid, 'Image:       baboon.tiff 512x512\n');
fprintf(fid, 'PSNR:        %.4f dB\n', psnr_val);
fprintf(fid, 'MSE:         %.4f\n', mse);
fprintf(fid, 'PSNR >= 30:  %s\n', string(psnr_val >= 30));
fclose(fid);
fprintf('Wrote psnr_result.txt\n');

% Save side-by-side comparison figure
fig = figure('Visible', 'off');
subplot(1,2,1);
imshow(uint8(img_gray)); title('Original');
subplot(1,2,2);
imshow(uint8(recon));    title(sprintf('Reconstructed (QF=%d, PSNR=%.2f dB)', qf, psnr_val));
saveas(fig, fullfile(fig_dir, 'comparison_fig.png'));
close(fig);
fprintf('Saved comparison_fig.png\n');
