function [tx_passband, data_bits, preamble, mseq, mseq_os, tx_meta] = generate_paper2_tx_signal(cfg)
% GENERATE_PAPER2_TX_SIGNAL Generates the full analytic-passband packet 
% including HFM preamble and DBPSK/DSSS payload.
    
    % 1. Preamble (HFM)
    preamble = generate_hfm_preamble(cfg);
    
    % 2. M-sequence
    mseq = load_paper2_mseq(cfg);
    mseq_os = repelem(mseq, cfg.samples_per_chip); % oversampled m-sequence
    
    % 3. Data & DBPSK
    data_bits = randi([0, 1], 1, cfg.num_data_bits);
    data_syms = 2 * data_bits - 1;
    
    diff_syms = zeros(1, cfg.num_data_bits + 1);
    diff_syms(1) = 1; % Reference symbol
    for i = 1:cfg.num_data_bits
        diff_syms(i+1) = diff_syms(i) * data_syms(i);
    end
    
    % 4. Spreading (Baseband)
    data_bb = kron(diff_syms, mseq_os);
    assert(length(data_bb) == cfg.num_diff_symbols * cfg.symbol_samples, 'Payload length error.');
    
    % 5. Upconversion to Analytic Passband
    t_data = (0:length(data_bb)-1) / cfg.fs;
    data_pb = data_bb .* exp(1j * 2 * pi * cfg.fc * t_data);
    
    % 6. Assembly
    guard = zeros(1, cfg.guard_samples);
    tx_passband = [preamble, guard, data_pb, guard];
    
    % 7. TX Meta
    tx_meta = struct();
    tx_meta.num_data_bits = cfg.num_data_bits;
    tx_meta.num_diff_symbols = cfg.num_diff_symbols;
    tx_meta.code_length = cfg.code_length;
    tx_meta.samples_per_chip = cfg.samples_per_chip;
    tx_meta.symbol_samples = cfg.symbol_samples;
    tx_meta.preamble_samples = cfg.preamble_samples;
    tx_meta.guard_samples = cfg.guard_samples;
    tx_meta.payload_start_index = length(preamble) + length(guard) + 1;
    tx_meta.payload_end_index = tx_meta.payload_start_index + length(data_pb) - 1;
    tx_meta.fs = cfg.fs;
    tx_meta.fc = cfg.fc;
end
