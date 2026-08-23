function metrics = compute_equalizer_metrics(h_true, w, h_hat, cfg)
% COMPUTE_EQUALIZER_METRICS Compute diagnostic metrics for equalizer evaluation.
%
% Inputs:
%   h_true - true Bellhop local cluster (padded to Lh if needed)
%   w      - equalizer taps (empty for NO-EQ)
%   h_hat  - estimated channel (for NMSE computation, empty for oracle/no-eq)
%   cfg    - configuration struct
%
% Outputs:
%   metrics - struct with diagnostic fields

    Lh = cfg.equalizer.channel_len;
    metrics = struct();
    
    % Pad h_true to Lh
    h_true = h_true(:);
    if length(h_true) < Lh
        h_true_padded = [h_true; zeros(Lh - length(h_true), 1)];
    else
        h_true_padded = h_true(1:Lh);
    end
    
    % RMS delay spread of true channel
    tap_power = abs(h_true_padded).^2;
    total_power = sum(tap_power);
    if total_power > 0
        tap_indices = (0:Lh-1)';
        mean_delay = sum(tap_indices .* tap_power) / total_power;
        rms_delay_spread = sqrt(sum((tap_indices - mean_delay).^2 .* tap_power) / total_power);
    else
        rms_delay_spread = 0;
    end
    metrics.input_channel_rms_delay_spread = rms_delay_spread;
    
    if isempty(w)
        % NO-EQ case: use true channel directly
        [~, main_idx] = max(abs(h_true_padded));
        main_energy = abs(h_true_padded(main_idx))^2;
        total_energy = sum(abs(h_true_padded).^2);
        metrics.main_tap_concentration = main_energy / max(total_energy, eps);
        metrics.residual_isi_fraction = max(0, (total_energy - main_energy) / max(total_energy, eps));
        
        metrics.combined_rms_delay_spread = rms_delay_spread;
        
        % PSLR
        sidelobes = abs(h_true_padded);
        sidelobes(main_idx) = 0;
        metrics.pslr = 20 * log10(max(sidelobes) / max(abs(h_true_padded(main_idx)), eps));
        
        metrics.noise_enhancement = 1.0;
    else
        % EQ case: compute combined response
        D = cfg.equalizer.decision_delay;
        g = conv(h_true_padded, w);
        
        main_idx = D + 1;
        if main_idx > length(g), main_idx = 1; end
        
        main_energy = abs(g(main_idx))^2;
        total_energy = sum(abs(g).^2);
        metrics.main_tap_concentration = main_energy / max(total_energy, eps);
        metrics.residual_isi_fraction = max(0, (total_energy - main_energy) / max(total_energy, eps));
        
        % Combined RMS Delay Spread
        tap_power_g = abs(g).^2;
        total_power_g = sum(tap_power_g);
        if total_power_g > 0
            tap_indices_g = (0:length(g)-1)';
            mean_delay_g = sum(tap_indices_g .* tap_power_g) / total_power_g;
            metrics.combined_rms_delay_spread = sqrt(sum((tap_indices_g - mean_delay_g).^2 .* tap_power_g) / total_power_g);
        else
            metrics.combined_rms_delay_spread = 0;
        end
        
        % PSLR
        sidelobes = abs(g);
        sidelobes(main_idx) = 0;
        metrics.pslr = 20 * log10(max(sidelobes) / max(abs(g(main_idx)), eps));
        
        metrics.noise_enhancement = sum(abs(w).^2);
    end
    
    % Channel estimation NMSE (only if h_hat provided)
    if ~isempty(h_hat)
        h_hat = h_hat(:);
        if length(h_hat) < Lh
            h_hat_padded = [h_hat; zeros(Lh - length(h_hat), 1)];
        else
            h_hat_padded = h_hat(1:Lh);
        end
        
        % Align complex scalar
        a = (h_hat_padded' * h_true_padded) / max(h_hat_padded' * h_hat_padded, eps);
        metrics.channel_est_nmse = norm(a * h_hat_padded - h_true_padded)^2 / max(norm(h_true_padded)^2, eps);
    else
        metrics.channel_est_nmse = NaN;
    end
end
