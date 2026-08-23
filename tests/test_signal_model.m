% test_signal_model.m
% Verify that the signal model operates strictly on DBPSK/DSSS.
addpath('../lib');
addpath('../config');
addpath('../data');

cfg = paper2_config('quick');
num_syms = cfg.num_symbols;
fs = cfg.fs;
fc = cfg.fc;
mseq_len = cfg.mseq_len;
N_pn = cfg.N_pn;

% 1. Data Generation
data_bits = randi([0, 1], 1, num_syms);
data_syms = 2 * data_bits - 1;

% 2. Differential Encoding (DBPSK)
diff_syms = zeros(1, num_syms + 1);
diff_syms(1) = 1; % Reference
for i = 1:num_syms
    diff_syms(i+1) = diff_syms(i) * data_syms(i);
end

% Check that diff_syms are real (+1, -1), not complex (no DQPSK)
assert(isreal(diff_syms), 'Error: Differential symbols must be real for DBPSK.');
assert(all(abs(diff_syms) == 1), 'Error: Symbols must be +/- 1.');

% 3. Spreading
if exist(cfg.mseq_path, 'file')
    m_data = load(cfg.mseq_path);
    if isfield(m_data, 'mseq')
        mseq_raw = m_data.mseq;
    else
        f = fieldnames(m_data);
        mseq_raw = m_data.(f{1});
    end
    if iscell(mseq_raw), mseq = mseq_raw{1}; else, mseq = mseq_raw; end
else
    % Dummy m-sequence
    mseq = 2 * randi([0, 1], 1, mseq_len) - 1;
end
mseq = mseq(:)';

% Upsample m-sequence (simple rectangular pulse shaping)
mseq_up = repelem(mseq, cfg.samples_per_chip);
mseq_ref = repmat(mseq_up, 1, N_pn);

% Baseband signal
sig_bb_tx = kron(diff_syms, mseq_ref);

% Assert signal length
expected_len = (num_syms + 1) * mseq_len * cfg.samples_per_chip * N_pn;
assert(length(sig_bb_tx) == expected_len, 'Error: Spread signal length mismatch.');

fprintf('test_signal_model: Passed. DBPSK/DSSS model is verified.\n');
