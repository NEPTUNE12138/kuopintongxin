% benchmark_paper2_receivers.m
% Benchmark MATLAB runtime for variants A, B, C, D, E.
clc; clear;
addpath('../lib');
addpath('../config');

cfg = paper2_config('quick');
variants = {'A', 'B', 'C', 'D', 'E'};
num_trials = 100;

% Setup dummy signal once
[sig_bb_tx, ~, preamble, ~, mseq_ref] = generate_paper2_tx_signal(cfg);
ch_file = cfg.channels{1, 1};
ch_data = load(ch_file);
f_names = fieldnames(ch_data);
h_chan = ch_data.(f_names{1}); h_chan = h_chan(:).';
sig_rx = filter(h_chan, 1, sig_bb_tx);
sig_rx = sig_rx + 0.1 * (randn(size(sig_rx)) + 1j*randn(size(sig_rx)));

fprintf('--- MATLAB Runtime Benchmark (per symbol processing) ---\n');
fprintf('Environment: MATLAB %s on %s\n', version, computer('arch'));

% Measure Overhead / Warmup
run_paper2_receiver_variant(sig_rx, preamble, mseq_ref, cfg, 'A');

res_runtime = zeros(length(variants), num_trials);

for v = 1:length(variants)
    var_name = variants{v};
    for t = 1:num_trials
        [~, ~, rt, ~] = run_paper2_receiver_variant(sig_rx, preamble, mseq_ref, cfg, var_name);
        res_runtime(v, t) = rt / cfg.num_symbols; % Normalize per symbol
    end
    
    mean_rt = mean(res_runtime(v, :)) * 1e3; % ms
    med_rt = median(res_runtime(v, :)) * 1e3; % ms
    
    % Complexity theoretical bound
    if var_name == 'E'
        % HVB-AKF (N_vb inner iterations)
        flops_theoretical = sprintf('O(N_{vb} n_x^3) = %d FLOPs', cfg.N_vb * 8); % Approximation for 2x2
    else
        % IAE-AKF (structural reg)
        flops_theoretical = 'O(n_x) = 16 FLOPs';
    end
    
    fprintf('Variant %s:\n  Mean Runtime: %.3f ms/symbol\n  Median Runtime: %.3f ms/symbol\n  Theoretical Complexity: %s\n', ...
        var_name, mean_rt, med_rt, flops_theoretical);
end
