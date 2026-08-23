function extract_paper_metrics(mode)
    if nargin < 1, mode = 'quick'; end
    cfg = paper2_config(mode);

    % We need to find the latest Validation result in results/mode/
    res_dir = fullfile('results', mode);
files = dir(fullfile(res_dir, 'paper2_ber_validation_*.mat'));
if isempty(files)
    warning('No raw results found to extract metrics from.');
    return;
end
[~, idx] = sort([files.datenum], 'descend');
res_file = fullfile(res_dir, files(idx(1)).name);
load(res_file, 'ber_results', 'variants');

out_dir = 'results_plots';
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

    is_paper = strcmp(mode, 'paper');
    
    if is_paper
        fid = fopen(fullfile(out_dir, 'paper_metrics.tex'), 'w');
        fprintf(fid, '%% Auto-generated metrics for WUWNET Paper 2\n');
    end
    csv_fid = fopen(fullfile(out_dir, sprintf('paper2_metrics_%s_%s.csv', mode, datestr(now, 'yyyymmdd_HHMMSS'))), 'w');
    fprintf(csv_fid, 'Metric,Value\n');

vE_idx = find(strcmp(variants, 'E'));

% 1. Find 1e-3 BER crossings for variant E
ber_target = 1e-3;
for i = 1:size(cfg.channels, 1)
    ch_name = cfg.channels{i, 2};
    clean_name = strrep(ch_name, ' ', ''); clean_name = strrep(clean_name, '(', ''); clean_name = strrep(clean_name, ')', '');
    
    ber_E = squeeze(mean(ber_results(i, :, vE_idx, :), 4, 'omitnan'));
    
    % Simple interpolation for crossing
    idx_below = find(ber_E <= ber_target, 1, 'first');
        % Mapping for safe LaTeX macro names (no numbers allowed in command names)
        ch_macros = {'CrossEPone', 'CrossEPtwo', 'CrossEPthree', 'CrossEPfour', 'CrossEPfive'};
        safe_macro = ch_macros{i};
        
        if isempty(idx_below)
            snr_cross = NaN;
            if is_paper, fprintf(fid, '\\newcommand{\\%s}{not reached}\n', safe_macro); end
            fprintf(csv_fid, 'CrossE_%s,NaN\n', clean_name);
        else
            if idx_below == 1
                snr_cross = cfg.snr_range(1);
            else
                % Simple linear interpolation (log-domain BER)
                x1 = cfg.snr_range(idx_below-1); y1 = log10(ber_E(idx_below-1));
                x2 = cfg.snr_range(idx_below);   y2 = log10(ber_E(idx_below));
                if isinf(y2) || isinf(y1) % If exact 0 BER occurs
                    snr_cross = cfg.snr_range(idx_below);
                else
                    snr_cross = x1 + (x2 - x1) * (log10(ber_target) - y1) / (y2 - y1);
                end
            end
            if is_paper, fprintf(fid, '\\newcommand{\\%s}{%.2f}\n', safe_macro, snr_cross); end
            fprintf(csv_fid, 'CrossE_%s,%.2f\n', clean_name, snr_cross);
        end
end

    if is_paper, fclose(fid); end
    fclose(csv_fid);
    fprintf('Exported paper metrics to CSV (and TEX if mode=paper)\n');
end
