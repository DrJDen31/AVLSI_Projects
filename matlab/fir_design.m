% =========================================================================
% Advanced VLSI - Course Project
% Phase 1: FIR Filter Design
% 
% Objective: Design a low-pass FIR filter
% - Taps: 100 (can be increased if needed)
% - Transition band: 0.2*pi ~ 0.23*pi rad/sample
% - Stopband attenuation: >= 80 dB
% =========================================================================

clear; clc; close all;

%% 1. Filter Specifications
N = 100;                % Initial number of taps (order = N-1)
Fpass = 0.2;            % Passband edge (normalized to pi)
Fstop = 0.23;           % Stopband edge (normalized to pi)
Apass = 1;              % Passband ripple (dB)
Astop = 80;             % Minimum stopband attenuation (dB)

% Since firpm requires frequencies normalized to 1 (Nyquist), multiply specs by 1
% Note: MATLAB firpm uses normalized frequency where 1.0 = Nyquist (pi rad/sample)
f = [0 Fpass Fstop 1];  % Frequency bands
m = [1 1 0 0];          % Desired magnitude response (1 for passband, 0 for stopband)

% Compute weights to enforce the 80dB stopband specification
% Weights are proportional to the inverse of the linear ripple target
delta_pass = (10^(Apass/20)-1) / (10^(Apass/20)+1);
delta_stop = 10^(-Astop/20);
w = [delta_stop/delta_pass 1]; % Emphasize stopband attenuation

%% 2. Design Filter (Parks-McClellan Remez Algorithm)
% The Parks-McClellan algorithm yields the optimal equiripple FIR filter
h_ideal = firpm(N-1, f, m, w);

%% 3. Frequency Response Analysis (Ideal / Unquantized)
[H, W] = freqz(h_ideal, 1, 1024);

% Plot the magnitude response
figure('Name', 'FIR Filter Frequency Response', 'Position', [100, 100, 800, 600]);
% Force Light Mode
set(gcf, 'Color', 'w');

subplot(2,1,1);
% Force Light Mode axes
set(gca, 'Color', 'w', 'XColor', 'k', 'YColor', 'k');

plot(W/pi, 20*log10(abs(H)), 'b', 'LineWidth', 1.5);
hold on;
grid on;

yline(-Astop, 'r--', 'Stopband Spec (-80dB)', 'LabelHorizontalAlignment', 'left');
xline(Fpass, 'k:');
xline(Fstop, 'k:');
text(Fpass - 0.01, -40, sprintf('Passband\nEdge (0.2\\pi)'), 'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle', 'BackgroundColor', 'w');
text(Fstop + 0.01, -40, 'Stopband Edge (0.23\pi)', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', 'BackgroundColor', 'w');

title(sprintf('Ideal %d-Tap FIR Filter Magnitude Response', N));
xlabel('Normalized Frequency (\times\pi rad/sample)');
ylabel('Magnitude (dB)');
axis([0 1 -120 10]);

% Analyze constraints to see if 100 taps is sufficient
stopband_attenuation_achieved = -max(20*log10(abs(H(W/pi >= Fstop))));
fprintf('\n--- Filter Design Summary ---\n');
fprintf('Number of Taps:            %d\n', N);
fprintf('Stopband Atten Spec:      > 80.00 dB\n');
fprintf('Stopband Atten Achieved:    %.2f dB\n', stopband_attenuation_achieved);

if stopband_attenuation_achieved >= Astop
    fprintf('Result: Spec MET with %d taps.\n', N);
else
    fprintf('Result: Spec FAILED. Need more taps.\n');
    fprintf('Run an automated iteration to find minimum required taps...\n');
    
    % Auto-iterate to find the minimum number of taps to meet spec
    N_calc = N;
    while stopband_attenuation_achieved < Astop
        N_calc = N_calc + 1;
        h_ideal = firpm(N_calc-1, f, m, w);
        [H_calc, W_calc] = freqz(h_ideal, 1, 1024);
        stopband_attenuation_achieved = -max(20*log10(abs(H_calc(W_calc/pi >= Fstop))));
    end
    fprintf('Required number of taps to meet 80dB spec: %d\n', N_calc);
    
    % Update the design with the correct number of taps
    N = N_calc;
    h_ideal = firpm(N-1, f, m, w);
    [H, W] = freqz(h_ideal, 1, 1024);
    
    % Replot
    plot(W/pi, 20*log10(abs(H)), 'g', 'LineWidth', 1.5);
    legend(sprintf('Initial Attempt (N=100)'), sprintf('Successful Design (N=%d)', N), 'Location', 'SouthWest');
    title(sprintf('Ideal %d-Tap FIR Filter Magnitude Response', N));
end

%% 4. Impulse Response and Pole-Zero Plot
subplot(2,2,3);
set(gca, 'Color', 'w', 'XColor', 'k', 'YColor', 'k');
stem(0:N-1, h_ideal, 'Marker', '.', 'MarkerSize', 10);
title('Impulse Response (Coefficients)');
xlabel('Sample (n)');
ylabel('Amplitude');
grid on;

subplot(2,2,4);
set(gca, 'Color', 'w', 'XColor', 'k', 'YColor', 'k');
zplane(h_ideal, 1);
title('Pole-Zero Plot');

% Export the figure
exportgraphics(gcf, '../img/FIR_Filter_Frequency_Response.png', 'Resolution', 300, 'BackgroundColor', 'w');

%% 5. Save Coefficients for Next Stage
save('fir_coefficients_ideal.mat', 'h_ideal', 'N', 'Fpass', 'Fstop', 'Apass', 'Astop');
fprintf('\nSaved ideal filter design to fir_coefficients_ideal.mat\n');
