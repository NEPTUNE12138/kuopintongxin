function run_paper2_full_pipeline(mode)
% RUN_PAPER2_FULL_PIPELINE End-to-end execution of the Paper 2 evaluation.
% Usage: run_paper2_full_pipeline('quick') or ('pilot') or ('paper')

    if nargin < 1
        mode = 'quick';
    end
    
    fprintf('=== Paper 2 Full Pipeline [%s] ===\n', upper(mode));
    
    % 1. Run all Gate tests
    fprintf('\n--- Running Gate Verification Tests ---\n');
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'lib'));
    addpath(fullfile(project_root, 'tests'));
    addpath(fullfile(project_root, 'src'));
    
    try
        test_signal_model;
        test_bellhop_loader;
        test_hybrid_cir_extraction;
        test_hvb_tracker;
        test_variant_consistency;
        test_early_late_sign;
        test_end_to_end_noiseless;
        test_end_to_end_bellhop_smoke;
        test_delay_tracking_ground_truth;
        test_ber_failure_statistics;
        test_variant_D_R_stability;
        test_reliability_calibration;
        test_time_warp_helper;
        test_trm_true_cir_metrics;
        test_variant_D_config_regression;
        test_ECAL_scale_transition;
        test_bellhop_cluster_selection;
        test_channel_full_convolution;
        test_cfar_raw_detection_no_fallback;
        fprintf('\nALL GATE TESTS PASSED!\n');
    catch ME
        fprintf('\n[!] GATE TEST FAILED: %s\n', ME.message);
        rethrow(ME);
    end
    
    % 2. Execution Phase
    fprintf('\n--- Execution Phase ---\n');
    
    % BER Validation
    main_WUWNET_Paper_Validation(mode);
    
    % Stress Test
    main_WUWNET_Paper_Stress(mode);
    
    % --- Round 4 Algorithm Freeze Diagnostics ---
    fprintf('\n--- Pre-Pilot Diagnostics (Round 4) ---\n');
    
    fprintf('Running CFAR Detection Calibration...\n');
    cfar_decision = diagnose_cfar_detection(mode);
    if ~cfar_decision.passed
        fprintf('[!] Setting TRM_PRIMARY_CONTRIBUTION = false\n');
    end
    
    fprintf('Running HVB Diagnostic & E-CAL Gate...\n');
    ecal_decision = diagnose_hvb_failure(mode);
    
    if ~ecal_decision.passed
        fprintf('\n[STOP] E-CAL failed scientific gate. Halting algorithm freeze pipeline.\n');
        return;
    end
    
    fprintf('Running C2 Minimax Selection...\n');
    plot_sensitivity_c2(mode);
    
    fprintf('Running TRM Diagnostic...\n');
    diagnose_trm_contribution(mode);
    
    fprintf('Running Final SNR Boundary Scan...\n');
    quick_snr_boundary_scan(mode);
    
    % 3. Ancillary Scripts and Plots
    fprintf('\n--- Ancillary Scripts and Plots ---\n');
    
    fprintf('Running TRM Ablation...\n');
    generate_paper_trm_ablation(mode);
    
    fprintf('Running Runtime Benchmark...\n');
    benchmark_paper2_receivers(mode);
    
    fprintf('Exporting Parameters...\n');
    export_paper_parameters(mode);
    
    fprintf('Plotting all Channels BER...\n');
    plot_all_3_channels_ber(mode);
    
    fprintf('Extracting Metrics...\n');
    extract_paper_metrics(mode);
    
    fprintf('\n=== Pipeline Completed Successfully ===\n');
end
