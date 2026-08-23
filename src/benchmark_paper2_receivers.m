function benchmark_paper2_receivers(mode)
% BENCHMARK_PAPER2_RECEIVERS Benchmark MATLAB runtime for variants A, B, C, D, E.
    if nargin < 1, mode = 'quick'; end
    
    this_file = mfilename('fullpath');
    src_dir = fileparts(this_file);
    project_root = fileparts(src_dir);
    addpath(fullfile(project_root, 'lib'));
    addpath(fullfile(project_root, 'config'));
    
    cfg = paper2_config(mode);
    variants = {'A', 'B', 'C', 'D', 'E'};
    num_trials = 100;
    
    % Setup dummy signal once
    [tx_pb, ~, preamble, ~, mseq_os, ~] = generate_paper2_tx_signal(cfg);
    ch_file = cfg.channels{1, 1};
    [h_chan, ~] = load_bellhop_cir(ch_file, cfg.fs);
    
    sig_rx = filter(h_chan, 1, tx_pb);
    sig_rx = sig_rx + 0.1 * (randn(size(sig_rx)) + 1j*randn(size(sig_rx)));
    
    [peak_idx, p_start, pay_start, mf, ~] = coarse_sync_from_preamble(sig_rx, preamble, cfg);
    sync_meta.peak_idx = peak_idx;
    sync_meta.preamble_start = p_start;
    sync_meta.payload_start = pay_start;
    sync_meta.mf = mf;
    
    fprintf('--- MATLAB Runtime Benchmark (per symbol processing) ---\n');
    fprintf('Environment: MATLAB %s on %s\n', version, computer('arch'));
    
    % Measure Overhead / Warmup
    run_paper2_receiver_variant(sig_rx, preamble, mseq_os, sync_meta, cfg, 'A');
    
    res_runtime = zeros(length(variants), num_trials);
    
    for v = 1:length(variants)
        var_name = variants{v};
        for t = 1:num_trials
            [~, rt, ~] = run_paper2_receiver_variant(sig_rx, preamble, mseq_os, sync_meta, cfg, var_name);
            res_runtime(v, t) = rt / cfg.num_diff_symbols; % Normalize per symbol
        end
        
        mean_rt = mean(res_runtime(v, :)) * 1e3; % ms
        med_rt = median(res_runtime(v, :)) * 1e3; % ms
        
        fprintf('Variant %s:\n  Mean Runtime: %.3f ms/symbol\n  Median Runtime: %.3f ms/symbol\n', ...
            var_name, mean_rt, med_rt);
    end
end
