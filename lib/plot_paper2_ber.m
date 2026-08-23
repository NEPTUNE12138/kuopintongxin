function plot_paper2_ber(results_file)
% PLOT_PAPER2_BER Generates BER vs SNR curves from results file.

    load(results_file, 'ber_results', 'cfg', 'variants', 'mode');
    
    num_channels = size(ber_results, 1);
    
    out_dir = 'results_plots';
    if ~exist(out_dir, 'dir')
        mkdir(out_dir);
    end
    
    markers = {'o-', 's-', 'd-', '^-', '*-'};
    colors = lines(length(variants));
    
    for ch_idx = 1:num_channels
        mean_ber = squeeze(mean(ber_results(ch_idx, :, :, :), 4)); % [num_snr x num_variants]
        
        figure('Name', sprintf('Channel %d BER', ch_idx), 'Position', [100, 100, 700, 500]);
        hold on; grid on;
        
        for v = 1:length(variants)
            semilogy(cfg.snr_db_range, mean_ber(:, v), markers{v}, 'LineWidth', 2, 'Color', colors(v,:), 'MarkerSize', 8);
        end
        
        set(gca, 'YScale', 'log');
        ylim([1e-4, 1]);
        xlim([min(cfg.snr_db_range), max(cfg.snr_db_range)]);
        
        xlabel('SNR (dB)', 'FontSize', 12, 'FontWeight', 'bold');
        ylabel('Bit Error Rate (BER)', 'FontSize', 12, 'FontWeight', 'bold');
        title(sprintf('BER Performance: %s (Mode: %s)', cfg.channels{ch_idx, 2}, mode), 'FontSize', 14);
        
        var_names = cell(1, length(variants));
        for v = 1:length(variants)
            def = paper2_variant_definition(variants{v});
            var_names{v} = def.name;
        end
        legend(var_names, 'Location', 'southwest', 'FontSize', 11);
        
        plot_file = fullfile(out_dir, sprintf('ber_ch%d_%s.png', ch_idx, mode));
        saveas(gcf, plot_file);
        fprintf('Saved plot: %s\n', plot_file);
    end
end
