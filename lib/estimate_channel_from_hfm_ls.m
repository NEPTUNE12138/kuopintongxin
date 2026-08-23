function [h_hat, est_meta] = estimate_channel_from_hfm_ls(rx_raw, preamble, sync_meta, cfg)
% ESTIMATE_CHANNEL_FROM_HFM_LS Dense preamble-aided regularized LS channel estimation.
%
% Uses the known HFM preamble as a training waveform and estimates a local
% FIR channel by regularized least squares with Tikhonov regularization.
% Noise is estimated from the guard interval between preamble and payload.
%
% Inputs:
%   rx_raw     - raw received waveform (passband)
%   preamble   - known HFM preamble waveform
%   sync_meta  - coarse synchronization metadata (.preamble_start, .payload_start)
%   cfg        - configuration struct with .equalizer fields
%
% Outputs:
%   h_hat      - estimated channel impulse response [Lh x 1]
%   est_meta   - metadata struct

    Lh = cfg.equalizer.channel_len;
    Np = length(preamble);
    
    est_meta = struct();
    est_meta.valid = true;
    
    % Extract training observation: preamble arrival region
    train_start = sync_meta.preamble_start;
    train_len = Np + Lh - 1;
    train_end = train_start + train_len - 1;
    
    if train_start < 1 || train_end > length(rx_raw)
        h_hat = zeros(Lh, 1);
        est_meta.valid = false;
        est_meta.reason = 'Training window out of bounds';
        return;
    end
    
    y_train = rx_raw(train_start:train_end).';  % column vector
    
    % Build convolution matrix P such that y_train ≈ P * h
    % P is (Np+Lh-1) x Lh
    P = zeros(Np + Lh - 1, Lh);
    for col = 1:Lh
        P(col:col+Np-1, col) = preamble(:);
    end
    
    % Noise estimate from guard interval
    guard_start = sync_meta.preamble_start + Np;
    guard_end = sync_meta.payload_start - 1;
    guard_len = guard_end - guard_start + 1;
    
    if guard_len < 10
        % Fallback: use a small default noise
        sigma_n2 = 1e-6;
    else
        % Use latter fraction of guard to avoid channel tail contamination
        frac = cfg.equalizer.noise_guard_fraction;
        guard_use_start = guard_start + round(guard_len * (1 - frac));
        guard_use_end = guard_end;
        if guard_use_end > length(rx_raw)
            guard_use_end = length(rx_raw);
        end
        noise_guard = rx_raw(guard_use_start:guard_use_end);
        sigma_n2 = mean(abs(noise_guard).^2);
    end
    
    % Signal power estimate from preamble region
    y_preamble_core = rx_raw(train_start:min(train_start+Np-1, length(rx_raw)));
    sigma_y2 = mean(abs(y_preamble_core).^2);
    sigma_s2 = max(sigma_y2 - sigma_n2, eps);
    eta = sigma_n2 / sigma_s2;
    
    % Regularized LS: scale-normalized Tikhonov
    G = P' * P;
    lambda_h = eta * trace(G) / Lh;
    
    cond_before = cond(G);
    h_hat = (G + lambda_h * eye(Lh)) \ (P' * y_train);
    cond_after = cond(G + lambda_h * eye(Lh));
    
    % Metadata
    est_meta.sigma_n2 = sigma_n2;
    est_meta.sigma_y2 = sigma_y2;
    est_meta.eta = eta;
    est_meta.lambda_h = lambda_h;
    est_meta.h_energy = sum(abs(h_hat).^2);
    est_meta.cond_before = cond_before;
    est_meta.cond_after = cond_after;
    
    if ~all(isfinite(h_hat))
        h_hat = zeros(Lh, 1);
        est_meta.valid = false;
        est_meta.reason = 'Non-finite channel estimate';
    end
end
