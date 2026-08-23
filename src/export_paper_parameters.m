% export_paper_parameters.m
clc; clear;
addpath('../config');
cfg = paper2_config('paper');

out_dir = '../generated';
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

fid = fopen(fullfile(out_dir, 'paper_parameters.tex'), 'w');
fprintf(fid, '%% Auto-generated simulation parameters for WUWNET Paper 2\n');
fprintf(fid, '\\newcommand{\\PaperFs}{%.0f}\n', cfg.fs);
fprintf(fid, '\\newcommand{\\PaperFc}{%.0f}\n', cfg.fc);
fprintf(fid, '\\newcommand{\\PaperPreambleBand}{%d--%d}\n', cfg.preamble_band(1), cfg.preamble_band(2));
fprintf(fid, '\\newcommand{\\PaperCodeLength}{%d}\n', cfg.mseq_len);
fprintf(fid, '\\newcommand{\\PaperSamplesPerChip}{%d}\n', cfg.samples_per_chip);
fprintf(fid, '\\newcommand{\\PaperFrameSymbols}{%d}\n', cfg.num_symbols);
fprintf(fid, '\\newcommand{\\PaperSNRRange}{%d \\sim %d}\n', min(cfg.snr_range), max(cfg.snr_range));
fprintf(fid, '\\newcommand{\\PaperMonteCarlo}{%d}\n', cfg.mc_trials);
fprintf(fid, '\\newcommand{\\PaperVBIterations}{%d}\n', cfg.N_vb);
fprintf(fid, '\\newcommand{\\PaperCtwo}{1/50}\n');
fclose(fid);
fprintf('Exported paper_parameters.tex\n');
