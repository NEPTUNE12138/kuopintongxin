function test_bellhop_cluster_selection()
% TEST_BELLHOP_CLUSTER_SELECTION Verifies local cluster logic.
    cfg = paper2_config('quick');
    cfg.bellhop_cluster_gap_s = 0.05;
    
    for i = 1:size(cfg.channels, 1)
        ch_file = cfg.channels{i, 1};
        [h_cluster, cluster_meta] = select_bellhop_local_cluster(ch_file, cfg);
        
        assert(cluster_meta.selected_path_count >= 1, 'Must select at least one path');
        assert(cluster_meta.retained_energy_ratio > 0 && cluster_meta.retained_energy_ratio <= 1, 'Energy ratio out of bounds');
        assert(cluster_meta.cluster_max_excess_delay <= cluster_meta.full_channel_max_excess_delay, 'Cluster delay spread exceeds full delay spread');
        
        % The gap between consecutive paths in the cluster must not exceed the limit
        diffs = diff(cluster_meta.selected_delays);
        assert(all(diffs <= cfg.bellhop_cluster_gap_s), 'Gap in cluster exceeds limit!');
        
        fprintf('Profile %d: Retained %.2f%% energy, max cluster delay %.4f s\n', i, cluster_meta.retained_energy_ratio*100, cluster_meta.cluster_max_excess_delay);
    end
    
    fprintf('test_bellhop_cluster_selection passed.\n');
end
