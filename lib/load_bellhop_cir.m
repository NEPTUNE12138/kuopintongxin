function [h, meta] = load_bellhop_cir(channel_file, fs)
% LOAD_BELLHOP_CIR Loads and formats Bellhop CIR into a discrete FIR filter.
% Only uses verified fields, avoiding generic guessing.

    if ~exist(channel_file, 'file')
        error('Bellhop file not found: %s', channel_file);
    end
    
    ch_data = load(channel_file);
    
    if ~isfield(ch_data, 'delay_clean')
        error('Invalid Bellhop file. Missing "delay_clean" field.');
    end
    
    delay_clean = ch_data.delay_clean;
    
    % Determine the correct amplitude field
    if isfield(ch_data, 'amp_clean_complex')
        amp_field = 'amp_clean_complex';
    elseif isfield(ch_data, 'amp_clean')
        amp_field = 'amp_clean';
    elseif isfield(ch_data, 'amp_norm')
        amp_field = 'amp_norm';
    else
        error('Invalid Bellhop file. Missing amplitude field.');
    end
    
    amp = ch_data.(amp_field);
    
    % FIR construction
    delay_rel = delay_clean - min(delay_clean);
    delay_samples = round(delay_rel * fs) + 1;
    
    h = zeros(1, max(delay_samples));
    
    % Accumulate colliding taps
    for p = 1:length(delay_samples)
        h(delay_samples(p)) = h(delay_samples(p)) + amp(p);
    end
    
    energy_before = norm(h);
    
    % Normalize to unit energy
    h = h / (norm(h) + eps);
    
    % Meta generation
    meta = struct();
    [~, name, ext] = fileparts(channel_file);
    meta.filename = [name, ext];
    meta.amplitude_field_used = amp_field;
    meta.num_arrivals = length(delay_clean);
    meta.absolute_delays = delay_clean;
    meta.relative_delays = delay_rel;
    meta.tap_indices = delay_samples;
    meta.energy_before_normalization = energy_before;
    meta.energy_after_normalization = norm(h);
    
    pdp = abs(h).^2;
    tau = (0:length(h)-1) / fs;
    meta.mean_delay = sum(tau .* pdp) / sum(pdp);
    meta.rms_delay_spread = sqrt(sum((tau - meta.mean_delay).^2 .* pdp) / sum(pdp));
    meta.max_excess_delay = tau(find(pdp > 0, 1, 'last')) - tau(find(pdp > 0, 1, 'first'));
    
    assert(isfinite(meta.rms_delay_spread), 'RMS delay spread must be finite.');
end
