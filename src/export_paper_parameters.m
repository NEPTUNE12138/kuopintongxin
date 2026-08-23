% export_paper_parameters.m
addpath('../config');
cfg = paper2_config('paper');

out_dir = 'results_plots';
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

fid = fopen(fullfile(out_dir, 'paper_parameters.tex'), 'w');
fprintf(fid, '%% Auto-generated simulation parameters for WUWNET Paper 2\n');
fprintf(fid, '\\newcommand{\\PaperFs}{%.0f}\n', cfg.fs);
fprintf(fid, '\\newcommand{\\PaperFc}{%.0f}\n', cfg.fc);
fprintf(fid, '\\newcommand{\\PaperPreambleBand}{%d--%d}\n', cfg.preamble_band(1), cfg.preamble_band(2));
fprintf(fid, '\\newcommand{\\PaperCodeLength}{%d}\n', cfg.code_length);
fprintf(fid, '\\newcommand{\\PaperSamplesPerChip}{%d}\n', cfg.samples_per_chip);
fprintf(fid, '\\newcommand{\\PaperDataBits}{%d}\n', cfg.num_data_bits);
fprintf(fid, '\\newcommand{\\PaperDiffSymbols}{%d}\n', cfg.num_diff_symbols);
fprintf(fid, '\\newcommand{\\PaperSNRRange}{%d \\sim %d}\n', min(cfg.snr_range), max(cfg.snr_range));
fprintf(fid, '\\newcommand{\\PaperMonteCarlo}{%d}\n', cfg.mc_trials_ber);
fprintf(fid, '\\newcommand{\\PaperVBIterations}{%d}\n', cfg.N_vb);
fprintf(fid, '\\newcommand{\\PaperCtwo}{1/%.0f}\n', 1/cfg.c2);
fclose(fid);
fprintf('Exported paper_parameters.tex\n');
