function [h_cluster, cluster_meta] = select_bellhop_local_cluster(channel_file, cfg)
% SELECT_BELLHOP_LOCAL_CLUSTER Extracts the first local arrival cluster from a Bellhop file.
% A cluster boundary is defined by a delay gap exceeding cfg.bellhop_cluster_gap_s.

    if ~exist(channel_file, 'file')
        error('Bellhop file not found: %s', channel_file);
    end
    
    ch_data = load(channel_file);
    
    if ~isfield(ch_data, 'delay_clean')
        error('Invalid Bellhop file. Missing "delay_clean" field.');
    end
    
    delay_clean = ch_data.delay_clean;
    
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
    
    if ~isfield(cfg, 'bellhop_cluster_gap_s')
        cfg.bellhop_cluster_gap_s = 0.05;
    end
    gap_limit = cfg.bellhop_cluster_gap_s;
    
    % 1. Sort arrivals by relative delay
    [delay_sorted, sort_idx] = sort(delay_clean);
    amp_sorted = amp(sort_idx);
    
    delay_rel = delay_sorted - delay_sorted(1);
    
    % 2 & 3. Select contiguous cluster
    diff_delays = diff(delay_rel);
    gap_idx = find(diff_delays > gap_limit, 1, 'first');
    
    if isempty(gap_idx)
        % No gap exceeds limit, take all
        sel_idx = 1:length(delay_rel);
    else
        % Take up to and including the arrival before the gap
        sel_idx = 1:gap_idx;
    end
    
    delay_cluster = delay_rel(sel_idx);
    amp_cluster = amp_sorted(sel_idx);
    
    % Construct cluster FIR
    delay_samples = round(delay_cluster * cfg.fs) + 1;
    h_cluster = zeros(1, max(delay_samples));
    for p = 1:length(delay_samples)
        h_cluster(delay_samples(p)) = h_cluster(delay_samples(p)) + amp_cluster(p);
    end
    
    energy_before = norm(h_cluster)^2;
    h_cluster = h_cluster / (norm(h_cluster) + eps);
    
    % Full channel properties for comparison
    delay_samples_full = round(delay_rel * cfg.fs) + 1;
    h_full = zeros(1, max(delay_samples_full));
    for p = 1:length(delay_samples_full)
        h_full(delay_samples_full(p)) = h_full(delay_samples_full(p)) + amp_sorted(p);
    end
    total_energy = norm(h_full)^2;
    
    cluster_meta = struct();
    cluster_meta.selected_arrival_indices = sort_idx(sel_idx);
    cluster_meta.selected_delays = delay_sorted(sel_idx);
    cluster_meta.selected_path_count = length(sel_idx);
    cluster_meta.selected_energy = energy_before;
    cluster_meta.total_energy = total_energy;
    cluster_meta.retained_energy_ratio = energy_before / (total_energy + eps);
    cluster_meta.cluster_max_excess_delay = max(delay_cluster);
    cluster_meta.full_channel_max_excess_delay = max(delay_rel);
    
    assert(cluster_meta.retained_energy_ratio > 0 && cluster_meta.retained_energy_ratio <= 1, ...
        'Invalid retained energy ratio: %f', cluster_meta.retained_energy_ratio);
end
