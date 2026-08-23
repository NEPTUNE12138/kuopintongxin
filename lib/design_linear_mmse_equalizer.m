function [w, eq_meta] = design_linear_mmse_equalizer(h_hat, eta, cfg)
% DESIGN_LINEAR_MMSE_EQUALIZER Regularized linear MMSE inverse filter design.
%
% Inputs:
%   h_hat  - estimated channel impulse response [Lh x 1]
%   eta    - noise-to-signal ratio estimate
%   cfg    - configuration struct
%
% Outputs:
%   w       - equalizer FIR taps [Leq x 1]
%   eq_meta - metadata struct

    Lh = cfg.equalizer.channel_len;
    Leq = cfg.equalizer.eq_len;
    D = cfg.equalizer.decision_delay;
    
    eq_meta = struct();
    eq_meta.valid = true;
    
    % Ensure h_hat is column
    h_hat = h_hat(:);
    if length(h_hat) < Lh
        h_hat = [h_hat; zeros(Lh - length(h_hat), 1)];
    end
    
    % Build convolution matrix H: (Lh+Leq-1) x Leq
    combined_len = Lh + Leq - 1;
    H = zeros(combined_len, Leq);
    for col = 1:Leq
        H(col:col+Lh-1, col) = h_hat;
    end
    
    % Target: unit impulse at decision delay
    d = zeros(combined_len, 1);
    d(D + 1) = 1;
    
    % Regularized MMSE
    G = H' * H;
    lambda_eq = eta * trace(G) / Leq;
    
    w = (G + lambda_eq * eye(Leq)) \ (H' * d);
    
    % Metadata
    eq_meta.lambda_eq = lambda_eq;
    eq_meta.decision_delay = D;
    eq_meta.w_energy = sum(abs(w).^2);
    eq_meta.combined_response = conv(h_hat, w);
    
    if ~all(isfinite(w))
        w = zeros(Leq, 1);
        w(1) = 1;
        eq_meta.valid = false;
        eq_meta.reason = 'Non-finite equalizer taps';
    end
end
