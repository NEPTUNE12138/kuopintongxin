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
        test_hvb_q_modes;
        test_hvb_innovation_telemetry;
        fprintf('\nALL GATE TESTS PASSED!\n');
    catch ME
        fprintf('\n[!] GATE TEST FAILED: %s\n', ME.message);
        rethrow(ME);
    end
    
    % 2. Final-Method Diagnostic (Q Attribution)
    fprintf('\n--- Final-Method Diagnostic (Round 5) ---\n');
    fprintf('Running HVB Q-Attribution Diagnostic...\n');
    diagnose_hvb_q_attribution(mode);
    
    % 3. CFAR Final Falsification
    fprintf('\n--- CFAR Final Falsification ---\n');
    fprintf('Running CFAR Detection Calibration...\n');
    cfar_decision = diagnose_cfar_detection('freeze');
    if ~cfar_decision.passed
        fprintf('[!] CFAR_EXTRACTION_FAILURE\n');
        fprintf('[!] HYBRID_TRM_NOT_SUPPORTED_AS_PRIMARY_CONTRIBUTION\n');
        fprintf('[!] Setting TRM_PRIMARY_CONTRIBUTION = false\n');
    end
    
    % 4. Execution Pipeline Control
    % Because E-CAL failed the predefined Round 4/5 gates, we MUST halt here.
    fprintf('\n[STOP] Pipeline halted due to E-CAL historical failure.\n');
    fprintf('FINAL_TRACKER_UNRESOLVED\n');
    fprintf('PILOT_BLOCKED\n');
    
    return;
end
