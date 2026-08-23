% main_WUWNET_Paper_Validation.m
% WUWNET Paper 2 Main BER Validation Script
clear; clc;
addpath('../lib');
addpath('../config');

% 1. Load config
cfg = paper2_config('paper'); % Use 'paper' mode for final results, or 'quick' for testing

variants = {'A', 'B', 'C', 'D', 'E'};
num_variants = length(variants);
snr_range = cfg.snr_range;
num_snr = length(snr_range);
num_channels = size(cfg.channels, 1);

%% Initialize Results Storage
res = struct();
for v = 1:num_variants
    var_name = variants{v};
    res.(var_name).total_errors = zeros(num_channels, num_snr);
    res.(var_name).total_bits = zeros(num_channels, num_snr);
    res.(var_name).sync_fails = zeros(num_channels, num_snr);
    res.(var_name).valid_trials = zeros(num_channels, num_snr);
    res.(var_name).runtime = zeros(num_channels, num_snr);
end

%% Simulation Loop
for ch_idx = 1:num_channels
    ch_file = cfg.channels{ch_idx, 1};
    ch_name = cfg.channels{ch_idx, 2};
    fprintf('\n--- Processing Channel: %s ---\n', ch_name);
    
    % Load Bellhop CIR
    if ~exist(ch_file, 'file')
        error('Bellhop channel file not found: %s', ch_file);
    end
    ch_data = load(ch_file);
    % Assuming channel data has a field 'h' or similar. 
    % For this script, we'll extract the first vector we find.
    f_names = fieldnames(ch_data);
    for fi = 1:length(f_names)
        if isnumeric(ch_data.(f_names{fi})) && length(ch_data.(f_names{fi})) > 10
            h_chan = ch_data.(f_names{fi});
            break;
        end
    end
    h_chan = h_chan(:).'; % Row vector
    
    for snr_idx = 1:num_snr
        snr_db = snr_range(snr_idx);
        fprintf('  SNR = %d dB ', snr_db);
        
        for trial = 1:cfg.mc_trials
            if mod(trial, 100) == 0, fprintf('.'); end
            
            % Generate TX signal
            [sig_bb_tx, data_bits, preamble, mseq, mseq_ref] = generate_paper2_tx_signal(cfg);
            
            % Channel Convolution
            sig_rx_clean = filter(h_chan, 1, sig_bb_tx);
            
            % Add Noise (Same realization for all variants)
            sig_pwr = var(sig_rx_clean);
            noise_pwr = sig_pwr / (10^(snr_db/10));
            noise = sqrt(noise_pwr/2) * (randn(size(sig_rx_clean)) + 1j*randn(size(sig_rx_clean)));
            sig_rx_noisy = sig_rx_clean + noise;
            
            % Evaluate Variants
            for v = 1:num_variants
                var_name = variants{v};
                
                try
                    [decoded_bits, track_err, runtime, meta] = run_paper2_receiver_variant(...
                        sig_rx_noisy, preamble, mseq_ref, cfg, var_name);
                        
                    res.(var_name).runtime(ch_idx, snr_idx) = res.(var_name).runtime(ch_idx, snr_idx) + runtime;
                    
                    if length(decoded_bits) == length(data_bits)
                        errors = sum(decoded_bits ~= data_bits);
                        res.(var_name).total_errors(ch_idx, snr_idx) = res.(var_name).total_errors(ch_idx, snr_idx) + errors;
                        res.(var_name).total_bits(ch_idx, snr_idx) = res.(var_name).total_bits(ch_idx, snr_idx) + length(data_bits);
                        res.(var_name).valid_trials(ch_idx, snr_idx) = res.(var_name).valid_trials(ch_idx, snr_idx) + 1;
                    else
                        res.(var_name).sync_fails(ch_idx, snr_idx) = res.(var_name).sync_fails(ch_idx, snr_idx) + 1;
                    end
                catch
                    res.(var_name).sync_fails(ch_idx, snr_idx) = res.(var_name).sync_fails(ch_idx, snr_idx) + 1;
                end
            end
        end
        fprintf(' Done.\n');
    end
end

%% Compute BER and Wilson CI
z = 1.96; % 95% CI
for v = 1:num_variants
    var_name = variants{v};
    n = res.(var_name).total_bits;
    e = res.(var_name).total_errors;
    
    p = e ./ max(1, n);
    res.(var_name).ber = p;
    
    % Wilson Score Interval
    denom = 1 + z^2 ./ max(1, n);
    center = (p + z^2 ./ (2 * max(1, n))) ./ denom;
    half_width = (z .* sqrt(p .* (1 - p) ./ max(1, n) + z^2 ./ (4 * max(1, n).^2))) ./ denom;
    
    res.(var_name).ci_lower = max(0, center - half_width);
    res.(var_name).ci_upper = min(1, center + half_width);
end

%% Save Results
if ~exist(cfg.results_dir, 'dir')
    mkdir(cfg.results_dir);
end

save(fullfile(cfg.results_dir, 'raw_results.mat'), 'res', 'cfg', 'variants');

% Export to CSV
csv_file = fopen(fullfile(cfg.results_dir, 'ber_results.csv'), 'w');
fprintf(csv_file, 'Channel,SNR_dB,Variant,BER,CI_Lower,CI_Upper,Sync_Fails\n');
for ch_idx = 1:num_channels
    for snr_idx = 1:num_snr
        for v = 1:num_variants
            var_name = variants{v};
            fprintf(csv_file, '%s,%d,%s,%e,%e,%e,%d\n', ...
                cfg.channels{ch_idx, 2}, snr_range(snr_idx), var_name, ...
                res.(var_name).ber(ch_idx, snr_idx), ...
                res.(var_name).ci_lower(ch_idx, snr_idx), ...
                res.(var_name).ci_upper(ch_idx, snr_idx), ...
                res.(var_name).sync_fails(ch_idx, snr_idx));
        end
    end
end
fclose(csv_file);

fprintf('\nValidation complete. Results saved to %s\n', cfg.results_dir);
