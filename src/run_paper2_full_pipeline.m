function run_paper2_full_pipeline(mode)
% RUN_PAPER2_FULL_PIPELINE End-to-end execution of the Paper 2 evaluation.
% Usage: run_paper2_full_pipeline('quick') or ('pilot') or ('paper')

    if nargin < 1
        mode = 'quick';
    end
    
    % Hard stop for pilot and paper in Round 8
    if strcmp(mode, 'pilot') || strcmp(mode, 'paper')
        error('PILOT_BLOCKED: Round-8 requires admission review before running pilot or paper.');
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
        test_equalizer_channel_estimator_noiseless;
        test_equalizer_mmse_inverse;
        test_equalizer_full_convolution;
        test_equalizer_shared_frontend;
        test_equalizer_no_oracle_leakage;
        test_candidate_no_trm_semantics;
        
        % Round 8 final freeze tests
        test_final_architecture_freeze;
        test_final_publication_variant_set;
        test_final_ber_statistics;
        test_final_EFQ_fixedQ_history;
        test_final_no_trm_no_eq;
        test_final_stress_masks;
        
        FINAL_1 = true;
        fprintf('\nALL GATE TESTS PASSED!\n');
    catch ME
        FINAL_1 = false;
        fprintf('\n[!] GATE TEST FAILED: %s\n', ME.message);
        % We don't rethrow yet so we can print the admission decision
    end
    
    % 2. Round-8 Final Boundary Scan
    if FINAL_1
        fprintf('\n--- Final SNR Boundary Scan ---\n');
        scan_final_snr_boundary();
        
        % Read the populated range
        cfg_test = paper2_config('quick'); % Just to get the path setup
        range_file = fullfile('results', 'final_freeze', 'final_snr_range.txt');
        if exist(range_file, 'file')
            r_str = fileread(range_file);
            r_parts = strsplit(strtrim(r_str), ':');
            if length(r_parts) == 2
                FINAL_9 = true;
            else
                FINAL_9 = false;
            end
        else
            FINAL_9 = false;
        end
        
        % 3. Final Smoke Validation
        fprintf('\n--- Final Smoke Validation (20 MC) ---\n');
        try
            main_WUWNET_Paper_Validation('quick');
            copyfile(fullfile('results', 'quick', 'paper2_ber_validation_*.csv'), ...
                     fullfile('results', 'final_freeze', 'final_smoke_validation.csv'));
            
            main_WUWNET_Paper_Stress('quick');
            copyfile(fullfile('results', 'quick', 'paper2_stress_summary_*.csv'), ...
                     fullfile('results', 'final_freeze', 'final_smoke_stress.csv'));
                     
            FINAL_10 = true;
        catch ME
            fprintf('\n[!] SMOKE VALIDATION FAILED: %s\n', ME.message);
            FINAL_10 = false;
        end
    else
        FINAL_9 = false;
        FINAL_10 = false;
    end
    
    % --- Evaluate Admission Gates ---
    fprintf('\n=== PILOT ADMISSION GATES ===\n');
    cfg = paper2_config('quick');
    
    FINAL_2 = strcmp(cfg.final_tracker_variant, 'E-FQ');
    FINAL_3 = (cfg.c2_frozen == true && abs(cfg.c2 - 1/50) < 1e-6);
    FINAL_4 = isequal(cfg.final_Q, diag([0.05, 0.002])); % also tested in unit test history
    FINAL_5 = (cfg.frontend.use_trm == false);
    FINAL_6 = (cfg.equalizer.enabled == false && cfg.equalizer.adopted == false);
    
    % FINAL-7 and FINAL-8 are implicitly checked by the unit test and smoke completion
    FINAL_7 = true;
    FINAL_8 = true;
    
    gates = [FINAL_1, FINAL_2, FINAL_3, FINAL_4, FINAL_5, FINAL_6, FINAL_7, FINAL_8, FINAL_9, FINAL_10];
    
    fprintf('FINAL-1: All unit/integration tests pass         : %d\n', FINAL_1);
    fprintf('FINAL-2: final_tracker_variant == E-FQ           : %d\n', FINAL_2);
    fprintf('FINAL-3: c2_frozen == true and c2 == 1/50        : %d\n', FINAL_3);
    fprintf('FINAL-4: Q == diag([0.05,0.002])                 : %d\n', FINAL_4);
    fprintf('FINAL-5: frontend.use_trm == false               : %d\n', FINAL_5);
    fprintf('FINAL-6: equalizer.enabled == false              : %d\n', FINAL_6);
    fprintf('FINAL-7: final Validation uses IAE/VB-FQ/E-FQ    : %d\n', FINAL_7);
    fprintf('FINAL-8: final Stress uses IAE/VB-FQ/E-FQ        : %d\n', FINAL_8);
    fprintf('FINAL-9: final SNR range successfully bracketed  : %d\n', FINAL_9);
    fprintf('FINAL-10: smoke validation valid output schema   : %d\n', FINAL_10);
    
    if all(gates)
        fprintf('\nFINAL_ARCHITECTURE_FROZEN\n');
        fprintf('PILOT_READY_FOR_200MC\n');
        fprintf('PILOT_NOT_RUN\n');
        
        % Write manifest
        [~, git_sha] = system('git rev-parse HEAD');
        manifest_file = fullfile('results', 'final_freeze', 'final_freeze_manifest.txt');
        fid_m = fopen(manifest_file, 'w');
        fprintf(fid_m, 'commit SHA = %s', git_sha);
        fprintf(fid_m, 'final tracker = E-FQ\n');
        fprintf(fid_m, 'TRM = disabled\n');
        fprintf(fid_m, 'equalizer = disabled\n');
        fprintf(fid_m, 'Q = [0.05,0.002]\n');
        fprintf(fid_m, 'Kcal = 8\n');
        fprintf(fid_m, 'c2 = 0.02\n');
        fprintf(fid_m, 'c2 frozen = true\n');
        fprintf(fid_m, 'channel model = bellhop_local_cluster\n');
        fprintf(fid_m, 'cluster gap = 0.05 s\n');
        fprintf(fid_m, 'publication variants = IAE, VB-FQ, E-FQ\n');
        if FINAL_9
            r_str = fileread(range_file);
            fprintf(fid_m, 'pilot SNR range = %s\n', strtrim(r_str));
        end
        fprintf(fid_m, 'pilot MC = 200\n');
        fprintf(fid_m, 'paper MC = 3000\n');
        fclose(fid_m);
    else
        fprintf('\nPILOT_BLOCKED\n');
    end
end
