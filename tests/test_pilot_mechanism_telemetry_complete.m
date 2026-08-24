function test_pilot_mechanism_telemetry_complete()
% TEST_PILOT_MECHANISM_TELEMETRY_COMPLETE Checks E-FQ telemetry completeness.
    cfg = paper2_config('quick');
    
    rng(1, 'twister');
    [tx_pb, data_bits, preamble, mseq, mseq_os, tx_meta] = generate_paper2_tx_signal(cfg);
    
    rx_final = tx_pb + 0.1 * randn(size(tx_pb)); % fake channel
    
    [peak_idx, p_start, pay_start, mf, ~] = coarse_sync_from_preamble(rx_final, preamble, cfg);
    sync_meta.peak_idx = peak_idx;
    sync_meta.preamble_start = p_start;
    sync_meta.payload_start = pay_start;
    sync_meta.mf = mf;
    
    [decoded_bits, ~, meta] = run_paper2_receiver_variant(rx_final, preamble, mseq_os, sync_meta, cfg, 'E-FQ');
    
    assert(strcmp(meta.status, 'SUCCESS'), 'Receiver must return SUCCESS');
    assert(~isempty(decoded_bits), 'Decoded bits should not be empty');
    
    assert(isfield(meta, 'm_reliability'), 'm_reliability missing');
    assert(isfield(meta, 'R_eff'), 'R_eff missing');
    assert(isfield(meta, 'R_vb'), 'R_vb missing');
    assert(isfield(meta, 'K_gain'), 'K_gain missing');
    assert(isfield(meta, 'Q_diag'), 'Q_diag missing');
    
    % Check that they have the required lengths
    N_syms = cfg.num_diff_symbols;
    assert(length(meta.m_reliability) == N_syms);
    assert(length(meta.R_eff) == N_syms);
    assert(length(meta.R_vb) == N_syms);
    assert(size(meta.K_gain, 2) == N_syms);
    assert(size(meta.Q_diag, 2) == N_syms);
    
    % Construct PRE / FADE / POST masks
    packet_duration = length(rx_final) / cfg.fs;
    fade_center = packet_duration / 2;
    fade_width = 0.1;
    t = (0:length(rx_final)-1) / cfg.fs;
    fade_env = 1 - 0.9 * exp(-0.5 * ((t - fade_center) / (fade_width / 3)).^2);
    
    sym_centers = sync_meta.payload_start + (0:N_syms-1) * cfg.symbol_samples + round(cfg.symbol_samples/2);
    sym_centers = min(length(fade_env), max(1, sym_centers));
    fade_env_at_centers = fade_env(sym_centers);
    fmask = fade_env_at_centers < 0.5;
    
    first_fade = find(fmask, 1, 'first');
    last_fade = find(fmask, 1, 'last');
    
    assert(~isempty(first_fade) && ~isempty(last_fade), 'Fade must cover some symbols');
    
    pre_idx = 1:(first_fade-1);
    fade_idx = first_fade:last_fade;
    post_idx = (last_fade+1):N_syms;
    
    assert(~isempty(pre_idx), 'PRE mask empty');
    assert(~isempty(fade_idx), 'FADE mask empty');
    assert(~isempty(post_idx), 'POST mask empty');
    
    % Phase medians
    m_f = median(meta.m_reliability(fade_idx), 'omitnan');
    m_p = median(meta.m_reliability(pre_idx), 'omitnan');
    
    ratio = meta.R_eff ./ max(meta.R_vb, eps);
    rr_f = median(ratio(fade_idx), 'omitnan');
    rr_p = median(ratio(pre_idx), 'omitnan');
    
    k_f = median(meta.K_gain(1, fade_idx), 'omitnan');
    k_p = median(meta.K_gain(1, pre_idx), 'omitnan');
    
    q11_f = median(meta.Q_diag(1, fade_idx), 'omitnan');
    q22_f = median(meta.Q_diag(2, fade_idx), 'omitnan');
    
    % Assert all finite
    req = [m_f, m_p, rr_f, rr_p, k_f, k_p, q11_f, q22_f];
    assert(all(isfinite(req)), 'Telemetry medians contain NaN');
    
    % Assert frozen Q
    assert(abs(q11_f - 0.05) < 1e-6, 'Q11 not locked at 0.05');
    assert(abs(q22_f - 0.002) < 1e-6, 'Q22 not locked at 0.002');
    
    disp('test_pilot_mechanism_telemetry_complete passed.');
end
