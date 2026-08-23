% test_hybrid_cir_extraction.m
addpath('../lib');
addpath('../config');

cfg = paper2_config('quick');
cfg.fs = 48000;
cfg.preamble_band = [3000, 7000];

% Create dummy preamble
t = 0:1/cfg.fs:0.02; % 20ms
preamble = chirp(t, 3000, 0.02, 7000); % HFM approx as LFM for test

% Create dummy CIR
cir = zeros(1, 1000);
cir(100) = 1;
cir(120) = 0.5;
cir(150) = 0.2; % multipath

g = conv(preamble, cir) + 0.05 * randn(1, length(preamble) + length(cir) - 1);
g_corr = xcorr(g, preamble);
g_corr = g_corr(length(g):end); % Only positive lags

[h_ext, gamma_os, gamma_acf, gamma_hybrid, mask, meta] = extract_cir_hybrid(g_corr, preamble, cfg);

assert(all(gamma_hybrid >= gamma_os), 'Error: Hybrid threshold must be >= OS threshold');
assert(meta.gamma_acf >= 0, 'Error: ACF floor must be non-negative');
assert(~any(isnan(h_ext)), 'Error: Extracted CIR contains NaN');
assert(~any(isinf(h_ext)), 'Error: Extracted CIR contains Inf');

% Check if main paths are detected (g_corr peak will be around the same indices)
[~, max_idx] = max(abs(g_corr));
assert(mask(max_idx), 'Error: Main path 1 not detected');

fprintf('test_hybrid_cir_extraction: Passed.\n');
