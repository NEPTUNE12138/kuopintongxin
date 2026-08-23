% main_WUWNET_Paper_Stress.m
% WUWNET Paper 2 Extreme Fading Stress Test
clear; clc;
addpath('../lib');
addpath('../config');

cfg = paper2_config('paper'); 
variants = {'C', 'D', 'E'};
num_variants = length(variants);
num_trials = cfg.mc_trials;

% Deep fade settings
fade_start_sym = 40;
fade_end_sym = 80;
fade_depth = 0.05; % amplitude scaling during fade
doppler_amp = 0.5; % sinusoidal Doppler stretch amplitude
doppler_freq = 0.2; % Hz

res = struct();
num_syms = cfg.num_symbols;
for v = 1:num_variants
    res.(variants{v}).track_err = zeros(num_trials, num_syms);
    res.(variants{v}).k_gain = zeros(num_trials, num_syms);
    res.(variants{v}).r_eff = zeros(num_trials, num_syms);
    res.(variants{v}).lambda = zeros(num_trials, num_syms);
    res.(variants{v}).m_k = zeros(num_trials, num_syms);
end

% Choose one representative channel
ch_file = cfg.channels{1, 1};
ch_data = load(ch_file);
f_names = fieldnames(ch_data);
h_chan = ch_data.(f_names{1});
h_chan = h_chan(:).';

fprintf('\n--- Running Extreme Fading Stress Test ---\n');
for trial = 1:num_trials
    if mod(trial, 10) == 0, fprintf('.'); end
    
    [sig_bb_tx, ~, preamble, ~, mseq_ref] = generate_paper2_tx_signal(cfg);
    
    % Apply Channel
    sig_rx = filter(h_chan, 1, sig_bb_tx);
    
    % Apply controlled Doppler & Fade
    t = (0:length(sig_rx)-1) / cfg.fs;
    doppler_phase = doppler_amp * sin(2 * pi * doppler_freq * t);
    
    % Approximate Doppler stretch by phase modulation
    sig_rx = sig_rx .* exp(1j * doppler_phase);
    
    % Apply deep fade
    % Convert symbol indices to sample indices roughly
    sym_len = cfg.mseq_len * cfg.N_pn * cfg.samples_per_chip;
    fade_start_idx = length(preamble) + round(0.05*cfg.fs) + fade_start_sym * sym_len;
    fade_end_idx = length(preamble) + round(0.05*cfg.fs) + fade_end_sym * sym_len;
    fade_mask = ones(size(sig_rx));
    fade_mask(fade_start_idx:min(fade_end_idx, length(fade_mask))) = fade_depth;
    
    sig_rx = sig_rx .* fade_mask;
    
    % Add Noise (e.g. -5 dB SNR outside fade)
    snr_db = -5;
    sig_pwr = var(sig_rx);
    noise = sqrt(sig_pwr / (2 * 10^(snr_db/10))) * (randn(size(sig_rx)) + 1j*randn(size(sig_rx)));
    sig_rx_noisy = sig_rx + noise;
    
    for v = 1:num_variants
        var_name = variants{v};
        try
            [~, track_err, ~, meta] = run_paper2_receiver_variant(sig_rx_noisy, preamble, mseq_ref, cfg, var_name);
            valid_len = min(num_syms, length(track_err));
            res.(var_name).track_err(trial, 1:valid_len) = track_err(1:valid_len);
            
            if isfield(meta, 'K_gain')
                res.(var_name).k_gain(trial, 1:valid_len) = meta.K_gain(1, 1:valid_len);
            end
            if isfield(meta, 'R_eff')
                res.(var_name).r_eff(trial, 1:valid_len) = meta.R_eff(1:valid_len);
            end
            if isfield(meta, 'Lambda')
                res.(var_name).lambda(trial, 1:valid_len) = meta.Lambda(1:valid_len);
            end
        catch
            % Skip failed trial
        end
    end
end
fprintf(' Done.\n');

% Calculate ensemble averages and RMSE
for v = 1:num_variants
    var_name = variants{v};
    res.(var_name).rmse = sqrt(mean(res.(var_name).track_err.^2, 1));
    res.(var_name).mean_k_gain = mean(res.(var_name).k_gain, 1);
    res.(var_name).mean_r_eff = mean(res.(var_name).r_eff, 1);
    res.(var_name).mean_lambda = mean(res.(var_name).lambda, 1);
    
    % 95% Confidence Band for RMSE (approx)
    std_err = std(abs(res.(var_name).track_err), 0, 1) / sqrt(num_trials);
    res.(var_name).ci_band = 1.96 * std_err;
end

save(fullfile(cfg.results_dir, 'stress_test_results.mat'), 'res', 'cfg', 'variants', 'fade_start_sym', 'fade_end_sym');
fprintf('Stress test complete. Results saved.\n');
