function [sig_bb_tx, data_bits, preamble, mseq, mseq_ref] = generate_paper2_tx_signal(cfg)
% GENERATE_PAPER2_TX_SIGNAL Generates the DBPSK/DSSS baseband signal and preamble
    
    fs = cfg.fs;
    fc = cfg.fc;
    num_syms = cfg.num_symbols;
    mseq_len = cfg.mseq_len;
    N_pn = cfg.N_pn;
    samples_per_chip = cfg.samples_per_chip;
    
    % 1. Preamble (HFM)
    B = cfg.preamble_band(2) - cfg.preamble_band(1);
    f0 = cfg.preamble_band(1);
    f1 = cfg.preamble_band(2);
    T_pre = 0.05; % 50ms preamble
    t_pre = 0:1/fs:T_pre-1/fs;
    % HFM: phase = 2*pi*(f0*f1*T_pre/(f1-f0)) * log(1 + (f1-f0)*t/(f0*T_pre))
    % For simplicity, we use LFM as an approximation if HFM is not strictly required for the waveform, 
    % or we implement true HFM.
    K = (f1 - f0) / T_pre;
    preamble = exp(1j * 2 * pi * (f0 * t_pre + 0.5 * K * t_pre.^2));
    
    % 2. M-sequence
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
        mseq = 2 * randi([0, 1], 1, mseq_len) - 1;
    end
    mseq = mseq(:)';
    
    mseq_up = repelem(mseq, samples_per_chip);
    mseq_ref = repmat(mseq_up, 1, N_pn);
    
    % 3. Data & DBPSK
    data_bits = randi([0, 1], 1, num_syms);
    data_syms = 2 * data_bits - 1;
    
    diff_syms = zeros(1, num_syms + 1);
    diff_syms(1) = 1; % Reference
    for i = 1:num_syms
        diff_syms(i+1) = diff_syms(i) * data_syms(i);
    end
    
    % 4. Spreading
    data_bb = kron(diff_syms, mseq_ref);
    
    % 5. Assembly
    guard = zeros(1, round(0.05 * fs)); % 50ms guard
    sig_bb_tx = [preamble, guard, data_bb, guard];
end
