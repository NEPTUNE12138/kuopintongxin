function run_paper2_pilot_200mc()
% RUN_PAPER2_PILOT_200MC Formal execution script for the 200-MC Pilot.

    fprintf('=== Paper 2 Authorized 200-MC Pilot ===\n');
    
    % Ensure path is set up
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'lib'));
    addpath(fullfile(project_root, 'tests'));
    addpath(fullfile(project_root, 'src'));
    
    cfg = paper2_config('pilot');
    
    % --- Integrity Gates ---
    fprintf('Checking Pre-Pilot Integrity Gates...\n');
    
    try
        assert(strcmp(cfg.final_tracker_variant, 'E-FQ'), 'Integrity Fail: final_tracker_variant must be E-FQ');
        assert(cfg.c2_frozen == true, 'Integrity Fail: c2 must be frozen');
        assert(abs(cfg.c2 - 1/50) < 1e-6, 'Integrity Fail: c2 must be 1/50');
        assert(isequal(cfg.final_Q, diag([0.05, 0.002])), 'Integrity Fail: Q must be diag([0.05, 0.002])');
        assert(cfg.reliability.calibration_symbols == 8, 'Integrity Fail: Kcal must be 8');
        assert(strcmp(cfg.hvb.q_adaptation_mode, 'fixed'), 'Integrity Fail: q_adaptation_mode must be fixed');
        assert(cfg.frontend.use_trm == false, 'Integrity Fail: TRM must be disabled');
        if isfield(cfg, 'trm_primary_contribution')
            assert(cfg.trm_primary_contribution == false, 'Integrity Fail: TRM contribution must be false');
        end
        assert(cfg.equalizer.enabled == false, 'Integrity Fail: Equalizer must be disabled');
        assert(cfg.equalizer.adopted == false, 'Integrity Fail: Equalizer adopted must be false');
        assert(isequal(cfg.snr_range, -16:1:-10), 'Integrity Fail: snr_range must be -16:1:-10');
        assert(isequal(cfg.pilot_snr_range, -16:1:-10), 'Integrity Fail: pilot_snr_range must be -16:1:-10');
        assert(cfg.stress_snr_db == 15, 'Integrity Fail: stress_snr_db must be 15');
        assert(cfg.mc_trials_ber == 200, 'Integrity Fail: mc_trials_ber must be 200');
        assert(cfg.mc_trials_stress == 200, 'Integrity Fail: mc_trials_stress must be 200');
        
        fprintf('Integrity Pre-Checks Passed.\n');
    catch ME
        fprintf('\nPILOT_ABORTED_INTEGRITY_FAILURE\n');
        rethrow(ME);
    end
    
    % --- Run Test Suite ---
    fprintf('\nRunning Test Suite (Round 8.1 Gates)...\n');
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
        test_equalizer_channel_estimator_noiseless;
        test_equalizer_mmse_inverse;
        test_equalizer_full_convolution;
        test_equalizer_shared_frontend;
        test_equalizer_no_oracle_leakage;
        test_candidate_no_trm_semantics;
        test_final_architecture_freeze;
        test_final_publication_variant_set;
        test_final_ber_statistics;
        test_final_EFQ_fixedQ_history;
        test_final_no_trm_no_eq;
        test_final_stress_masks;
        test_pilot_snr_range_persistence;
        test_final_stress_snr_frozen;
        test_final_smoke_artifact_paths;
        
        test_pilot_config_exact;
        test_pilot_variant_fairness;
        test_pilot_result_schema;
        test_pilot_raw_pairing;
        test_pilot_no_parameter_mutation;
        test_pilot_no_paper_execution;
        
        fprintf('All unit and integration tests passed.\n');
    catch ME
        fprintf('\nPILOT_ABORTED_INTEGRITY_FAILURE\n');
        rethrow(ME);
    end
    
    % --- Execution ---
    fprintf('\n=== Launching 200-MC Validation ===\n');
    [val_csv, val_meta] = main_WUWNET_Paper_Validation('pilot', -16:1:-10, 200);
    
    fprintf('\n=== Launching 200-MC Stress ===\n');
    [stress_csv, stress_meta] = main_WUWNET_Paper_Stress('pilot', 15, 200);
    
    % Find the MAT files corresponding to the CSV files
    [val_dir, val_name, ~] = fileparts(val_csv);
    val_mat = fullfile(val_dir, [val_name, '.mat']);
    
    [stress_dir, stress_name, ~] = fileparts(stress_csv);
    % stress MAT has a different naming convention in the function (paper2_stress_mode_timestamp.mat)
    % but we can just use dir to find it by timestamp, or change main_WUWNET_Paper_Stress to return mat_file.
    % Alternatively, analyze_paper2_pilot will just scan for the latest MAT file in results/pilot.
    
    % --- Post-Pilot Analysis ---
    fprintf('\n=== Launching Pilot Analysis ===\n');
    analyze_paper2_pilot();
    
    fprintf('\n=== PILOT COMPLETE ===\n');
end
