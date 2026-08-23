function plot_all_3_channels_ber(mode)
    if nargin < 1, mode = 'quick'; end
    cfg = paper2_config(mode);
    res_dir = fullfile('results', mode);
files = dir(fullfile(res_dir, 'paper2_ber_validation_*.mat'));
if isempty(files)
    error('Results file not found. Run run_paper2_full_pipeline(''paper'') first.');
end
[~, idx] = sort([files.datenum], 'descend');
res_file = fullfile(res_dir, files(idx(1)).name);

load(res_file, 'ber_results', 'cfg', 'variants'); 

channels = cfg.channels;
num_channels = size(channels, 1);
SNR_range = cfg.snr_range;

% Aesthetics
font_name = 'Times New Roman';
font_size_label = 13;
font_size_legend = 11;
font_size_title = 14;
font_size_tick = 11;
line_width_thick = 2.5;
line_width_thin = 1.5;

% Colors and markers for A, B, C, D, E
colors = {
    [0.2, 0.2, 0.2];       % A
    [0.850, 0.325, 0.098]; % B
    [0.929, 0.694, 0.125]; % C
    [0.000, 0.447, 0.741]; % D
    [0.850, 0.1, 0.1]      % E
};
markers = {'-s', '-d', '-o', '-^', '-p'};

legend_strs = cell(1, length(variants));
for v = 1:length(variants)
    def = paper2_variant_definition(variants{v});
    legend_strs{v} = def.name;
end

out_dir = 'results_plots';
if ~exist(out_dir, 'dir'), mkdir(out_dir); end

for i = 1:num_channels
    ch_title = channels{i, 2};
    fig = figure('Name', ['BER Comparison - ' ch_title], 'Position', [100+i*50, 100+i*50, 650, 500], 'Color', 'w');
    
    hold on;
    for v = 1:length(variants)
        var_name = variants{v};
        % ber_results is [ch, snr, var, mc]
        ber = squeeze(mean(ber_results(i, :, v, :), 4, 'omitnan'));
        
        lw = line_width_thin;
        ms = 8;
        if strcmp(var_name, 'E')
            lw = line_width_thick;
            ms = 10;
        end
        
        semilogy(SNR_range, max(ber, 1e-6), markers{v}, 'LineWidth', lw, ...
            'Color', colors{v}, 'MarkerSize', ms, 'MarkerFaceColor', 'w', ...
            'MarkerEdgeColor', colors{v});
    end
    
    grid on; set(gca, 'YMinorGrid', 'on', 'XMinorGrid', 'on', 'GridAlpha', 0.4, 'GridLineStyle', ':', 'FontSize', font_size_tick, 'FontName', font_name);
    set(gca, 'TickDir', 'in', 'YScale', 'log');
    
    title(['BER Performance in ' ch_title], 'FontSize', font_size_title, 'FontWeight', 'bold', 'FontName', font_name);
    xlabel('Signal-to-Noise Ratio (dB)', 'FontSize', font_size_label, 'FontWeight', 'bold', 'FontName', font_name);
    ylabel('Bit Error Rate', 'FontSize', font_size_label, 'FontWeight', 'bold', 'FontName', font_name);
    
    lgd = legend(legend_strs, 'Location', 'southwest');
    set(lgd, 'FontName', font_name, 'FontSize', font_size_legend, 'EdgeColor', 'none', 'Color', 'none');
    ylim([1e-4, 1.0]); xlim([min(SNR_range), max(SNR_range)]);
    
    out_name = sprintf('Fig_BER_Paper2_Ch%d.png', i);
    out_path = fullfile(out_dir, out_name);
    
    exportgraphics(fig, out_path, 'Resolution', 300);
    close(fig);
    fprintf('Saved %s\n', out_name);
end
end
