% generate_testvectors.m - emit test_vectors.hex and golden_coeffs_fixed.txt

%% --- Setup ---
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

% Fixed-point cosine matrix (Q2.14)
frac_bits = 14;
C_int     = round(C * 2^frac_bits);
out_bits  = 12;

%% --- Task 11a: Extract first 16 8x8 blocks ---
num_blocks = 4096;
out_dir    = fullfile(fileparts(mfilename('fullpath')), 'outputs');

%% --- Task 11b: Write pixels to test_vectors.hex (one byte per line, $readmemh) ---
fid_pix = fopen(fullfile(out_dir, 'test_vectors.hex'), 'w');
block_count = 0;
for br = 1:8:size(img_gray,1)-7
    for bc = 1:8:size(img_gray,2)-7
        if block_count >= num_blocks, break; end
        blk = img_gray(br:br+7, bc:bc+7);
        % Write row-major, one pixel per line
        for r = 1:8
            for c = 1:8
                fprintf(fid_pix, '%02X\n', uint8(blk(r,c)));
            end
        end
        block_count = block_count + 1;
    end
    if block_count >= num_blocks, break; end
end
fclose(fid_pix);
fprintf('Wrote %d blocks (%d pixels) to test_vectors.hex\n', num_blocks, num_blocks*64);

%% --- Task 11c: Write 12-bit fixed-point DCT coefficients to golden_coeffs_fixed.txt ---
fid_coef = fopen(fullfile(out_dir, 'golden_coeffs_fixed.txt'), 'w');
block_count = 0;
for br = 1:8:size(img_gray,1)-7
    for bc = 1:8:size(img_gray,2)-7
        if block_count >= num_blocks, break; end
        blk = img_gray(br:br+7, bc:bc+7);

        % Fixed-point DCT (Q2.14 cosines, 12-bit output)
        tmp = C_int * blk;
        tmp = round(tmp / 2^frac_bits);
        Y   = tmp * C_int';
        Y   = round(Y / 2^frac_bits);
        max_val = 2^(out_bits-1) - 1;
        min_val = -2^(out_bits-1);
        Y = max(min(Y, max_val), min_val);

        % Write row-major, one coeff per line as 16-bit sign-extended hex
        for r = 1:8
            for c = 1:8
                val = int16(Y(r,c));          % sign-extend to 16-bit
                fprintf(fid_coef, '%04X\n', typecast(val, 'uint16'));
            end
        end
        block_count = block_count + 1;
    end
    if block_count >= num_blocks, break; end
end
fclose(fid_coef);
fprintf('Wrote %d blocks (%d coefficients) to golden_coeffs_fixed.txt\n', num_blocks, num_blocks*64);
