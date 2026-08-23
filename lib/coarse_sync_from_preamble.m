function [peak_idx, preamble_start, payload_start, mf, sync_metric] = coarse_sync_from_preamble(rx, preamble, cfg)
% COARSE_SYNC_FROM_PREAMBLE Finds packet start via matched filtering with preamble.

    mf = conv(rx, conj(fliplr(preamble)));
    [~, peak_idx] = max(abs(mf));
    
    preamble_start = peak_idx - length(preamble) + 1;
    payload_start = preamble_start + length(preamble) + cfg.guard_samples;
    
    % Normalized correlation metric for confidence
    preamble_energy = norm(preamble)^2;
    % Extract segment that matched
    seg_start = max(1, preamble_start);
    seg_end = min(length(rx), preamble_start + length(preamble) - 1);
    
    if seg_end - seg_start + 1 == length(preamble)
        rx_energy = norm(rx(seg_start:seg_end))^2;
        sync_metric = abs(mf(peak_idx)) / (sqrt(rx_energy * preamble_energy) + eps);
    else
        sync_metric = 0; % Edge case where preamble is truncated
    end
end
