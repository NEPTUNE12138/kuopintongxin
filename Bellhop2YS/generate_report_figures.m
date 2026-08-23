%% 自动生成汇报用图片脚本
feature('DefaultCharacterSet', 'UTF8');
clc; clear; close all;

artifact_dir = 'C:\Users\NEPTUNE\.gemini\antigravity-ide\brain\e0af00b3-5e36-49fd-8c5c-0debeb56d1ab';

%% 1. 生成区域横向对比图 (柱状图 & 雷达图)
load('sparsity_analysis_results.mat');
results_table = struct();
for i = 1:length(all_results)
    results_table(i).gini = all_results(i).metrics.gini;
    results_table(i).l1_l2_norm = all_results(i).metrics.l1_l2_norm;
    results_table(i).n_eff_paths = all_results(i).metrics.n_eff_paths;
    results_table(i).energy_top3 = all_results(i).metrics.energy_topK;
    results_table(i).n_clusters = all_results(i).clusters.n_clusters;
    results_table(i).rms_delay_ms = all_results(i).stats.rms_delay_spread_ms;
    results_table(i).coherence_bw_Hz = all_results(i).stats.coherence_bw_50_Hz;
    results_table(i).K_factor_dB = all_results(i).stats.K_factor_dB;
    results_table(i).first_cluster_pwr = all_results(i).clusters.first_cluster_power_ratio;
end
zone_names = {'深海第一会聚区', '海底可靠声路径区', '深海声影区信道'};
figure_sparsity_comparison(results_table, zone_names);

figs = findobj('Type', 'figure');
saveas(figs(1), fullfile(artifact_dir, 'comp_radar.png'));
saveas(figs(2), fullfile(artifact_dir, 'comp_bars.png'));
close all;

%% 2. 生成距离演变趋势图
load('range_sweep_100m_110m.mat');
figure_param_vs_range(results);
figs = findobj('Type', 'figure');
saveas(figs(1), fullfile(artifact_dir, 'range_trend.png'));
close all;

%% 3. 生成深度演变趋势图
load('depth_sweep_100m_20km.mat');
soundspeeds_ori = importdata('SSP_202305.mat');
[~, sofar_idx] = min(soundspeeds_ori(:, 2));
sofar_depth = soundspeeds_ori(sofar_idx, 1);
Sea_depth = 4325;
figure_param_vs_depth(results, soundspeeds_ori, sofar_depth, Sea_depth);

figs = findobj('Type', 'figure');
saveas(figs(1), fullfile(artifact_dir, 'depth_scatter.png'));
saveas(figs(2), fullfile(artifact_dir, 'depth_dual_axis.png'));
saveas(figs(3), fullfile(artifact_dir, 'depth_ssp.png'));
close all;

fprintf('所有图片已生成并保存在: %s\n', artifact_dir);
