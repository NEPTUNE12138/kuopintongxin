function mseq = load_paper2_mseq(cfg)
% LOAD_PAPER2_MSEQ Loads the verified 31-chip bipolar m-sequence
    
    if ~exist(cfg.mseq_path, 'file')
        error('mseq.mat not found at absolute path: %s', cfg.mseq_path);
    end
    
    m_data = load(cfg.mseq_path);
    if isfield(m_data, 'mseq')
        mseq_raw = m_data.mseq;
    else
        f = fieldnames(m_data);
        mseq_raw = m_data.(f{1});
    end
    
    if iscell(mseq_raw)
        idx = cfg.code_index;
        if size(mseq_raw, 1) >= idx
            mseq = mseq_raw{idx, 1};
        else
            mseq = mseq_raw{1, 1}; % Fallback if index out of bounds
        end
    else
        mseq = mseq_raw;
    end
    
    mseq = mseq(:).'; % Row vector
    mseq(mseq == 0) = -1;
    
    assert(length(mseq) == cfg.code_length, 'Loaded mseq length (%d) mismatch with config (%d).', length(mseq), cfg.code_length);
    assert(all(ismember(mseq, [-1, 1])), 'Loaded mseq contains invalid values. Must be bipolar {-1, 1}.');
end
