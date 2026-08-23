function cfg = paper2_config(mode)
    % PAPER2_CONFIG Configuration for WUWNET Paper 2
    % Inputs:
    %   mode - 'quick' or 'paper'
    
    if nargin < 1
        mode = 'quick';
    end
    
    %% Base Paths
    % Use absolute or relative paths from project root
    cfg.mseq_path = 'data/mseq.mat';
    cfg.results_dir = 'results_plots/WUWNET_Paper/';
    
    %% Load M-Sequence to get dynamic length
    if exist(cfg.mseq_path, 'file')
        mseq_data = load(cfg.mseq_path);
        if isfield(mseq_data, 'mseq')
            m_temp = mseq_data.mseq;
            if iscell(m_temp), mseq_len = length(m_temp{1}); else, mseq_len = length(m_temp); end
        else
            % Fallback if field name differs
            fields = fieldnames(mseq_data);
            m_temp = mseq_data.(fields{1});
            if iscell(m_temp), mseq_len = length(m_temp{1}); else, mseq_len = length(m_temp); end
        end
    else
        warning('mseq.mat not found at %s. Falling back to length 31.', cfg.mseq_path);
        mseq_len = 31;
    end
    
    %% Signal Model & Modulation (DBPSK / DSSS)
    cfg.fs = 48000;             % Sampling frequency (Hz)
    cfg.fc = 5000;              % Carrier frequency (Hz)
    cfg.preamble_band = [3000, 7000]; % HFM preamble bandwidth
    
    cfg.mseq_len = mseq_len;    % M-sequence chips
    cfg.N_pn = 6;               % Cycles of m-sequence per symbol
    cfg.num_symbols = 120;      % Short frame differential symbols
    
    % Derived
    cfg.samples_per_chip = round(cfg.fs / cfg.fc); 
    cfg.symbol_dur = cfg.N_pn * cfg.mseq_len * cfg.samples_per_chip / cfg.fs; % seconds
    
    %% Simulation & Monte Carlo
    cfg.snr_range = -14:1:0;
    
    switch mode
        case 'quick'
            cfg.mc_trials = 20;
        case 'paper'
            cfg.mc_trials = 3000;
        otherwise
            cfg.mc_trials = 20;
    end
    
    cfg.random_seed_policy = 'shuffle'; % Or fixed seed if required
    
    %% Tracking (HVB-AKF & DLL)
    cfg.early_late_spacing = 0.5; % Chips
    cfg.iae_window = 50;
    
    % HVB parameters
    cfg.vb_forgetting_factor = 0.99;
    cfg.N_vb = 3;               % Inner VB iterations
    cfg.c2 = 1/50;              % Heteroscedastic penalty hyperparameter
    cfg.Lambda_freeze = 100;    % Threshold to freeze Q updates
    
    %% Hybrid Threshold TRM & OS-CFAR
    cfg.os_cfar.pfa = 1e-4;
    cfg.os_cfar.train_cells = 40; % Total training cells (both sides)
    cfg.os_cfar.guard_cells = 10; % Total guard cells
    cfg.os_cfar.order_idx = 0.75; % e.g. 75th percentile of training cells
    
    cfg.kappa_side = 1.5;       % ACF sidelobe safety factor
    
    %% Channels (Bellhop)
    cfg.channels = {
        '../Bellhop2YS/channel_15m_20km_34m.mat', 'Shallow 20km (34m)';
        '../Bellhop2YS/channel_15m_20km_3467m.mat', 'Shallow 20km (3467m)';
        '../Bellhop2YS/channel_100m_45km_110m.mat', 'Deep 45km'
    }; 

end
