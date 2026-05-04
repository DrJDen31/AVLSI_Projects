% dct_golden.m - floating-point 8x8 DCT golden model

%% --- Task 1: Load image, convert to grayscale double ---
img_path = fullfile(fileparts(mfilename('fullpath')), 'images', 'baboon.tiff');
raw = imread(img_path);

if size(raw, 3) == 3
    img_gray = double(rgb2gray(raw));   % convert RGB -> grayscale -> double
else
    img_gray = double(raw);
end

fprintf('Image loaded: %dx%d, range [%.1f, %.1f]\n', ...
    size(img_gray,1), size(img_gray,2), min(img_gray(:)), max(img_gray(:)));

%% --- Task 2: Floating-point 1D DCT on an 8-element vector ---
function X = dct1d(x)
    N = length(x);
    X = zeros(1, N);
    for k = 0:N-1
        if k == 0
            alpha = sqrt(1/N);
        else
            alpha = sqrt(2/N);
        end
        n = 0:N-1;
        X(k+1) = alpha * sum(x(:).' .* cos(pi*(2*n+1)*k / (2*N)));
    end
end

% Validate against MATLAB built-in dct()
test_vec = img_gray(1, 1:8);
my_result   = dct1d(test_vec);
matlab_result = dct(test_vec);
max_err = max(abs(my_result - matlab_result));
fprintf('1D DCT max error vs MATLAB dct(): %.2e\n', max_err);

%% --- Task 3: 2D 8x8 DCT (row-then-column) validated against dct2() ---
function Y = dct2d(block)
    % Apply 1D DCT to each row, then each column
    tmp = zeros(8, 8);
    for r = 1:8
        tmp(r, :) = dct1d(block(r, :));
    end
    Y = zeros(8, 8);
    for c = 1:8
        Y(:, c) = dct1d(tmp(:, c).').';
    end
end

test_block    = img_gray(1:8, 1:8);
my_2d         = dct2d(test_block);
matlab_2d     = dct2(test_block);
max_err_2d    = max(abs(my_2d(:) - matlab_2d(:)));
fprintf('2D DCT max error vs MATLAB dct2(): %.2e\n', max_err_2d);

%% --- Task 4: Tile image into 8x8 blocks, compute DCT, save to golden_coeffs.txt ---
[rows, cols] = size(img_gray);
out_path = fullfile(fileparts(mfilename('fullpath')), 'outputs', 'golden_coeffs.txt');
fid = fopen(out_path, 'w');

num_blocks = 0;
for br = 1 : 8 : rows-7
    for bc = 1 : 8 : cols-7
        block = img_gray(br:br+7, bc:bc+7);
        coeffs = dct2d(block);
        for r = 1:8
            fprintf(fid, '%12.6f %12.6f %12.6f %12.6f %12.6f %12.6f %12.6f %12.6f\n', coeffs(r,:));
        end
        fprintf(fid, '\n');
        num_blocks = num_blocks + 1;
    end
end
fclose(fid);
fprintf('Wrote %d blocks to %s\n', num_blocks, out_path);
