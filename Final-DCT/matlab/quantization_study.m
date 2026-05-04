% quantization_study.m - JPEG Q-table / quality factor PSNR study

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

%% --- Task 8: Standard JPEG luminance Q-table + quality-factor scaling ---
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

function Q = qtable(Q_base, qf)
    % JPEG spec quality-factor scaling
    if qf <= 0,   qf = 1;   end
    if qf > 100,  qf = 100; end
    if qf < 50
        scale = 5000 / qf;
    else
        scale = 200 - 2*qf;
    end
    Q = floor((Q_base * scale + 50) / 100);
    Q = max(min(Q, 255), 1);
end

fprintf('Q-table at QF=50 (standard):\n');
disp(qtable(Q_base, 50));

%% --- Task 9: PSNR vs quality factor QF = 10:10:100 ---
[rows, cols] = size(img_gray);
qf_values = 10:10:100;
psnr_vals = zeros(size(qf_values));

for qi = 1:length(qf_values)
    qf = qf_values(qi);
    Q  = qtable(Q_base, qf);
    recon = zeros(rows, cols);

    for br = 1:8:rows-7
        for bc = 1:8:cols-7
            blk      = img_gray(br:br+7, bc:bc+7);
            dct_blk  = C * blk * C';
            quant    = round(dct_blk ./ Q);
            dequant  = quant .* Q;
            recon_blk = C' * dequant * C;
            recon(br:br+7, bc:bc+7) = recon_blk;
        end
    end

    recon = max(min(recon, 255), 0);
    mse   = mean((img_gray(:) - recon(:)).^2);
    if mse == 0
        psnr_vals(qi) = Inf;
    else
        psnr_vals(qi) = 10*log10(255^2 / mse);
    end
    fprintf('QF = %3d -> PSNR = %.2f dB\n', qf, psnr_vals(qi));
end

%% --- Task 10: Plot and save psnr_vs_qf.png ---
fig_dir = fullfile(fileparts(mfilename('fullpath')), 'outputs', 'figures');
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

fig = figure('Visible', 'off');
plot(qf_values, psnr_vals, 'b-o', 'LineWidth', 1.5, 'MarkerFaceColor', 'b');
xlabel('JPEG Quality Factor');
ylabel('PSNR (dB)');
title('PSNR vs. JPEG Quality Factor (Baboon, 512×512)');
grid on;
yline(30, 'r--', 'PSNR = 30 dB floor', 'LabelHorizontalAlignment', 'left');
saveas(fig, fullfile(fig_dir, 'psnr_vs_qf.png'));
close(fig);
fprintf('Saved psnr_vs_qf.png\n');

% Report which QF values meet the 30 dB floor
passing = qf_values(psnr_vals >= 30);
fprintf('QF values meeting PSNR >= 30 dB: %s\n', num2str(passing));
