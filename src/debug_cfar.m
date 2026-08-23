this_file = mfilename('fullpath');
src_dir = fileparts(this_file);
project_root = fileparts(src_dir);
addpath(fullfile(project_root, 'lib'));
addpath(fullfile(project_root, 'config'));

cfg = paper2_config('quick');
[h_cluster, cluster_meta] = select_bellhop_local_cluster(cfg.channels{1, 1}, cfg);

true_taps = cluster_meta.selected_delays;
true_tap_samples = round(true_taps * cfg.fs) + 1;

preamble = generate_hfm_preamble(cfg);
rx_clean = conv(preamble, h_cluster, 'full');
g_raw = conv(rx_clean, conj(fliplr(preamble)));

expected_peaks = length(preamble) + true_tap_samples - 1;

[max_val, max_idx] = max(abs(g_raw));
fprintf('Max peak is at %d. Expected first tap is at %d\n', max_idx, expected_peaks(1));

cfg_test = cfg;
cfg_test.os_cfar.pfa = 1e-2;
cfg_test.os_cfar.order_idx = 0.50;
cfg_test.kappa_side = 0; % OS-CFAR only for this diagnostic

[h_ext, ~, ~, ~, ~, ext_meta] = extract_cir_hybrid(g_raw, preamble, cfg_test);

detected_indices = find(ext_meta.raw_os_mask);
disp('Detected indices:');
disp(detected_indices);
disp('Expected peaks:');
disp(expected_peaks);
