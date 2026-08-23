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
        test_mf_diagnostic_window_bounds;
        test_fixedq_candidate_definition;
        test_vbfq_ablation_definition;
        test_frontend_trm_override;
        test_receiver_telemetry_histories;
        test_phase_mask_reset;
        fprintf('\nALL GATE TESTS PASSED!\n');
    catch ME
        fprintf('\n[!] GATE TEST FAILED: %s\n', ME.message);
        rethrow(ME);
    end
    
    % 2. Fixed-Q Held-Out Confirmatory Experiment (Round 6)
    fprintf('\n--- Fixed-Q Held-Out Confirmation (Round 6) ---\n');
    confirm_fixedq_tracker_heldout(mode);
    
    % Pipeline terminates here — Pilot/Paper blocked while final tracker unresolved
    fprintf('\nPILOT NOT RUN\n');
    fprintf('PAPER NOT RUN\n');
end
