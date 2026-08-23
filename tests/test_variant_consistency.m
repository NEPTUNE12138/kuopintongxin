% test_variant_consistency.m
addpath('../lib');
addpath('../config');

cfg = paper2_config('quick');

% Minimal dummy data
sig_bb = randn(1, 1000);
preamble = randn(1, 100);
mseq_ref = randn(1, 100);

try
    [dec_A, hist_A] = run_paper2_receiver_variant(sig_bb, preamble, mseq_ref, cfg, 'A');
    [dec_B, hist_B] = run_paper2_receiver_variant(sig_bb, preamble, mseq_ref, cfg, 'B');
    [dec_C, hist_C] = run_paper2_receiver_variant(sig_bb, preamble, mseq_ref, cfg, 'C');
    [dec_D, hist_D] = run_paper2_receiver_variant(sig_bb, preamble, mseq_ref, cfg, 'D');
    [dec_E, hist_E] = run_paper2_receiver_variant(sig_bb, preamble, mseq_ref, cfg, 'E');
catch ME
    disp(getReport(ME, 'extended', 'hyperlinks', 'off'));
    error('Variant wrapper failed');
end

fprintf('test_variant_consistency: Passed.\n');
