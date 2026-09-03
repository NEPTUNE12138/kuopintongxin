function main_WUWNET_Paper_Strengthening_Stage3_v2()
% MAIN_WUWNET_PAPER_STRENGTHENING_STAGE3_V2 Bellhop Profile Statistics
    mode = 'paper';
    cfg = paper2_config(mode);
    num_channels = size(cfg.channels, 1);
    
    out_dir = fullfile('results', 'paper_strengthening_v2');
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end
    
    out_ProfileID = cell(num_channels, 1);
    out_RetainedPaths = zeros(num_channels, 1);
    out_ClusterSpan_ms = zeros(num_channels, 1);
    out_RMSDelaySpread_ms = zeros(num_channels, 1);
    out_DominantEnergyFraction = zeros(num_channels, 1);
    
    fprintf('\n=== Starting STAGE 3 V2: Bellhop Profile Statistics ===\n');
    fprintf('Profile | Tx/Rx/Range | Retained paths | Cluster span (ms) | RMS delay spread (ms)\n');
    
    for ch_idx = 1:num_channels
        ch_file = cfg.channels{ch_idx, 1};
        profile_id = sprintf('P%d', ch_idx);
        desc = cfg.channels{ch_idx, 2};
        
        [h_cluster, cluster_meta] = select_bellhop_local_cluster(ch_file, cfg);
        
        % Calculate stats from the original discrete paths to avoid sampling artifacts
        ch_data = load(ch_file);
        amp = ch_data.amp_clean_complex;
        [delay_sorted, sort_idx] = sort(ch_data.delay_clean);
        amp_sorted = amp(sort_idx);
        
        sel_idx = cluster_meta.selected_arrival_indices;
        
        % We need the amplitudes for the selected paths
        % But sel_idx in cluster_meta might be indices into the sorted array?
        % Let's look at select_bellhop_local_cluster.m: 
        % cluster_meta.selected_arrival_indices = sort_idx(sel_idx)
        % So it returns the original indices.
        
        delays = ch_data.delay_clean(sel_idx);
        delays = delays - min(delays); % Relative
        
        amps = amp_sorted(1:length(sel_idx)); % Wait, the original code used sel_idx on the sorted arrays.
        % Actually, the delays of the cluster are in cluster_meta.selected_delays
        delays = cluster_meta.selected_delays;
        delays = delays - min(delays);
        
        % we can get the amps from the sorted array
        amps_cluster = amp_sorted(1:length(delays));
        P = abs(amps_cluster).^2;
        
        retained_paths = length(delays);
        cluster_span_ms = (max(delays) - min(delays)) * 1000;
        
        mean_delay = sum(P .* delays) / sum(P);
        rms_delay_spread_ms = sqrt(sum(P .* (delays - mean_delay).^2) / sum(P)) * 1000;
        
        dominant_energy_fraction = max(P) / sum(P);
        
        out_ProfileID{ch_idx} = profile_id;
        out_RetainedPaths(ch_idx) = retained_paths;
        out_ClusterSpan_ms(ch_idx) = cluster_span_ms;
        out_RMSDelaySpread_ms(ch_idx) = rms_delay_spread_ms;
        out_DominantEnergyFraction(ch_idx) = dominant_energy_fraction;
        
        fprintf('%s | %s | %d | %.3f | %.3f\n', profile_id, desc, retained_paths, cluster_span_ms, rms_delay_spread_ms);
    end
    
    T = table(out_ProfileID, out_RetainedPaths, out_ClusterSpan_ms, out_RMSDelaySpread_ms, out_DominantEnergyFraction, ...
        'VariableNames', {'ProfileID', 'RetainedPaths', 'ClusterSpan_ms', 'RMSDelaySpread_ms', 'DominantEnergyFraction'});
    
    csv_file = fullfile(out_dir, 'Bellhop_Profile_Statistics_v2.csv');
    writetable(T, csv_file);
    fprintf('Exported %s\n', csv_file);
    
    % Generate Audit MD
    doc_path = fullfile('docs', 'BELLHOP_PROFILE_AUDIT.md');
    fid = fopen(doc_path, 'w');
    fprintf(fid, '# Bellhop Profile Statistics Audit\n\n');
    fprintf(fid, 'This document reproduces the multipath statistics for the retained local cluster.\n\n');
    fprintf(fid, '## Retention Rule\n');
    fprintf(fid, 'Used the exact same `select_bellhop_local_cluster.m` as the final paper pipeline:\n');
    fprintf(fid, '- Sort arrivals by delay.\n');
    fprintf(fid, '- Retain earliest contiguous cluster.\n');
    fprintf(fid, '- Stop before first gap > 50 ms.\n\n');
    fprintf(fid, '## Reproduced Statistics\n\n');
    fprintf(fid, '| Profile | Tx/Rx/Range | Retained paths | Cluster span (ms) | RMS delay spread (ms) | Dominant Energy Fraction |\n');
    fprintf(fid, '|---------|-------------|----------------|-------------------|-----------------------|--------------------------|\n');
    for ch_idx = 1:num_channels
        desc = cfg.channels{ch_idx, 2};
        fprintf(fid, '| P%d | %s | %d | %.3f | %.3f | %.3f |\n', ...
            ch_idx, desc, out_RetainedPaths(ch_idx), out_ClusterSpan_ms(ch_idx), out_RMSDelaySpread_ms(ch_idx), out_DominantEnergyFraction(ch_idx));
    end
    fclose(fid);
end
