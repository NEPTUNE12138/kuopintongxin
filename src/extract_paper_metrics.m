% extract_paper_metrics.m
% Extracts final metrics from raw results for the paper
clc; clear;
addpath('../config');
cfg = paper2_config('paper');

res_file = fullfile(cfg.results_dir, 'raw_results.mat');
if ~exist(res_file, 'file')
    warning('No raw results found to extract metrics from.');
    return;
end
load(res_file);

out_dir = '../generated';
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

fid = fopen(fullfile(out_dir, 'paper_metrics.tex'), 'w');
csv_fid = fopen(fullfile(out_dir, 'paper_metrics.csv'), 'w');
fprintf(fid, '%% Auto-generated metrics for WUWNET Paper 2\n');
fprintf(csv_fid, 'Metric,Value\n');

% 1. Find 1e-3 BER crossings for variant E
ber_target = 1e-3;
for i = 1:size(cfg.channels, 1)
    ch_name = cfg.channels{i, 2};
    clean_name = strrep(ch_name, ' ', ''); clean_name = strrep(clean_name, '(', ''); clean_name = strrep(clean_name, ')', '');
    
    ber_E = res.E.ber(i, :);
    
    % Simple interpolation for crossing
    idx_below = find(ber_E <= ber_target, 1, 'first');
    if isempty(idx_below)
        snr_cross = NaN;
        fprintf(fid, '\\newcommand{\\CrossE%s}{not reached}\n', clean_name);
        fprintf(csv_fid, 'CrossE_%s,NaN\n', clean_name);
    else
        if idx_below == 1
            snr_cross = cfg.snr_range(1);
        else
            x1 = cfg.snr_range(idx_below-1); y1 = log10(max(1e-6, ber_E(idx_below-1)));
            x2 = cfg.snr_range(idx_below);   y2 = log10(max(1e-6, ber_E(idx_below)));
            snr_cross = x1 + (x2 - x1) * (log10(ber_target) - y1) / (y2 - y1);
        end
        fprintf(fid, '\\newcommand{\\CrossE%s}{%.2f}\n', clean_name, snr_cross);
        fprintf(csv_fid, 'CrossE_%s,%.2f\n', clean_name, snr_cross);
    end
end

fclose(fid);
fclose(csv_fid);
fprintf('Exported paper_metrics.tex and .csv\n');
