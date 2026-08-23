function cfg = paper2_config(mode)
    % PAPER2_CONFIG Configuration for WUWNET Paper 2
    % Inputs:
    %   mode - 'quick', 'pilot', or 'paper'
    
    if nargin < 1
        mode = 'quick';
    end
    
    %% Base Paths
    this_file = mfilename('fullpath');
    config_dir = fileparts(this_file);
    project_root = fileparts(config_dir);
    
    cfg.project_root = project_root;
    cfg.mseq_path = fullfile(project_root, 'data', 'mseq.mat');
    cfg.bellhop_dir = fullfile(project_root, 'Bellhop2YS');
    cfg.results_dir = fullfile(project_root, 'results_plots', 'WUWNET_Paper', mode);
    cfg.generated_dir = fullfile(project_root, 'generated');
    
    %% System Parameters (Fixed for Paper 2)
    cfg.fs = 48000;
    cfg.fc = 5000;
    cfg.preamble_band = [3000, 7000]; % 4 kHz bandwidth
    
    % Spread Spectrum Definition
    cfg.code_index = 2; % mseq{2,1}
    cfg.samples_per_chip = 6;
    cfg.code_length = 31;
    cfg.symbol_samples = cfg.code_length * cfg.samples_per_chip;
    
    % Frame Definition
    cfg.num_data_bits = 120;
    cfg.num_diff_symbols = cfg.num_data_bits + 1; % 1 reference symbol
    cfg.preamble_duration = 0.05; % 50ms
    cfg.preamble_samples = round(cfg.preamble_duration * cfg.fs);
    cfg.guard_duration = 0.05; % 50ms
    cfg.guard_samples = round(cfg.guard_duration * cfg.fs);
    
    %% Channels (Bellhop)
    cfg.channels = {
        fullfile(cfg.bellhop_dir, 'channel_15m_20km_34m.mat'), 'Profile P1: Tx15m / 20km / Rx34m';
        fullfile(cfg.bellhop_dir, 'channel_15m_20km_3467m.mat'), 'Profile P2: Tx15m / 20km / Rx3467m';
        fullfile(cfg.bellhop_dir, 'channel_100m_45km_110m.mat'), 'Profile P3: Tx100m / 45km / Rx110m'
    }; 

    %% Algorithm Hyperparameters
    % TRM / OS-CFAR
    cfg.os_cfar.train_cells = 30;
    cfg.os_cfar.guard_cells = 4;
    cfg.os_cfar.pfa = 1e-4;
    cfg.os_cfar.order_idx = 0.75; % e.g., 75th percentile
    cfg.cfar_max_lag = round(cfg.symbol_samples * 1.5); % Look for paths within 1.5 symbol delays
    
    % HVB Tracker
    cfg.N_vb = 4; % VB coordinate ascent iterations
    cfg.c2 = 1/50; % Heteroscedastic penalty scaling factor
    cfg.q_freeze_reliability = 0.2; % Freeze Q if m_k < 0.2
    
    % Variant D heuristic penalty parameters
    cfg.var_D_A = 50;
    cfg.var_D_b = 8;
    
    % Early-Late Tracking window size
    cfg.W_size = 5; 
    
    %% Simulation & Monte Carlo Modes
    cfg.master_seed = 20260823;
    cfg.snr_range = -14:1:0;
    
    switch mode
        case 'quick'
            cfg.mc_trials_ber = 20;
            cfg.mc_trials_stress = 20;
            cfg.mc_trials_sens = 20;
        case 'pilot'
            cfg.mc_trials_ber = 200;
            cfg.mc_trials_stress = 200;
            cfg.mc_trials_sens = 100;
        case 'paper'
            cfg.mc_trials_ber = 3000;
            cfg.mc_trials_stress = 3000;
            cfg.mc_trials_sens = 300;
        otherwise
            error('Unknown mode: %s. Use quick, pilot, or paper.', mode);
    end
end
