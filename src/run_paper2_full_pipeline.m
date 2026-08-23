function run_paper2_full_pipeline(mode)
% RUN_PAPER2_FULL_PIPELINE End-to-end execution of the Paper 2 evaluation.
% Usage: run_paper2_full_pipeline('quick') or ('pilot') or ('paper')

    if nargin < 1
        mode = 'quick';
    end
    
    % Hard stop for pilot and paper in Round 8.1
    if strcmp(mode, 'pilot') || strcmp(mode, 'paper')
        error('PILOT_BLOCKED: Round-8.1 requires admission review before running pilot or paper.');
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
        
        % Round 8/8.1 final freeze and integrity tests
        test_final_architecture_freeze;
        test_final_publication_variant_set;
        test_final_ber_statistics;
        test_final_EFQ_fixedQ_history;
        test_final_no_trm_no_eq;
        test_final_stress_masks;
        test_pilot_snr_range_persistence;
        test_final_stress_snr_frozen;
        test_final_smoke_artifact_paths;
        
        FINAL_1 = true;
        fprintf('\nALL GATE TESTS PASSED!\n');
    catch ME
        FINAL_1 = false;
        fprintf('\n[!] GATE TEST FAILED: %s\n', ME.message);
    end
    
    % 2. Round-8 Final Boundary Scan (Skip rerun unless requested, but we verify from existing CSV)
    FINAL_9 = false;
    bound_file = fullfile('results', 'final_freeze', 'final_snr_boundary.csv');
    if FINAL_1 && exist(bound_file, 'file')
        try
            b_data = readtable(bound_file, 'VariableNamingRule', 'preserve');
            p1_lower_valid = any(b_data.Channel == 1 & b_data.SNR_dB == -16 & strcmp(b_data.Variant, 'E-FQ') & b_data.FER_Overall >= 0.50);
            p1_upper_valid = any(b_data.Channel == 1 & b_data.SNR_dB == -12 & strcmp(b_data.Variant, 'E-FQ') & b_data.FER_Overall <= 0.05);
            
            p2_lower_valid = any(b_data.Channel == 2 & b_data.SNR_dB == -13 & strcmp(b_data.Variant, 'E-FQ') & b_data.FER_Overall >= 0.50);
            p2_upper_valid = any(b_data.Channel == 2 & b_data.SNR_dB == -10 & strcmp(b_data.Variant, 'E-FQ') & b_data.FER_Overall <= 0.05);
            
            p3_lower_valid = any(b_data.Channel == 3 & b_data.SNR_dB == -16 & strcmp(b_data.Variant, 'E-FQ') & b_data.FER_Overall >= 0.50);
            p3_upper_valid = any(b_data.Channel == 3 & b_data.SNR_dB == -12 & strcmp(b_data.Variant, 'E-FQ') & b_data.FER_Overall <= 0.05);
            
            if p1_lower_valid && p1_upper_valid && p2_lower_valid && p2_upper_valid && p3_lower_valid && p3_upper_valid
                FINAL_9 = true;
                sum_file = fullfile('results', 'final_freeze', 'final_boundary_summary.txt');
                f_s = fopen(sum_file, 'w');
                fprintf(f_s, 'P1 lower = -16 dB\nP1 upper = -12 dB\n\nP2 lower = -13 dB\nP2 upper = -10 dB\n\nP3 lower = -16 dB\nP3 upper = -12 dB\n\ncommon range = -16:-10 dB\n');
                fclose(f_s);
            end
        catch
            FINAL_9 = false;
        end
    end
    
    % 3. Final Smoke Validation
    FINAL_10 = false;
    FINAL_7 = false;
    FINAL_8 = false;
    
    if FINAL_1
        fprintf('\n--- Final Smoke Validation (20 MC) ---\n');
        try
            val_dst = fullfile('results', 'final_freeze', 'final_smoke_validation.csv');
            stress_dst = fullfile('results', 'final_freeze', 'final_smoke_stress.csv');
            
            if exist(val_dst, 'dir'), rmdir(val_dst, 's'); end
            if exist(stress_dst, 'dir'), rmdir(stress_dst, 's'); end
            
            [val_csv, val_meta] = main_WUWNET_Paper_Validation('quick', -16:1:-10, 20);
            copyfile(val_csv, val_dst);
            
            [stress_csv, stress_meta] = main_WUWNET_Paper_Stress('quick', 15, 20);
            copyfile(stress_csv, stress_dst);
            
            if isequal(val_meta.variants_internal, {'A','VB-FQ','E-FQ'}) && ...
               isequal(val_meta.variant_labels, {'IAE','VB-FQ','E-FQ'}) && ...
               (val_meta.frontend_use_trm == false) && ...
               (val_meta.equalizer_enabled == false) && ...
               isequal(val_meta.snr_range, -16:1:-10) && ...
               (val_meta.num_mc == 20)
                FINAL_7 = true;
            end
            
            if isequal(stress_meta.variants_internal, {'A','VB-FQ','E-FQ'}) && ...
               (stress_meta.frontend_use_trm == false) && ...
               (stress_meta.equalizer_enabled == false) && ...
               (stress_meta.stress_snr_db == 15) && ...
               stress_meta.has_all_profiles
                FINAL_8 = true;
            end
            
            if exist(val_dst, 'file') && exist(stress_dst, 'file')
                v_data = readtable(val_dst, 'VariableNamingRule', 'preserve');
                s_data = readtable(stress_dst, 'VariableNamingRule', 'preserve');
                
                v_schema_ok = (height(v_data) == 63) && ...
                              length(unique(v_data.Channel)) == 3 && ...
                              length(unique(v_data.SNR_dB)) == 7 && ...
                              length(unique(v_data.Variant)) == 3 && ...
                              all(ismember({'Trials_Total', 'Wilson_Upper_ValidBER'}, v_data.Properties.VariableNames));
                              
                s_schema_ok = (height(s_data) == 9) && ...
                              length(unique(s_data.Channel)) == 3 && ...
                              length(unique(s_data.Variant)) == 3 && ...
                              all(ismember({'Median_Q11_Fade', 'Median_Q22_Fade'}, s_data.Properties.VariableNames));
                              
                efq_stress = s_data(strcmp(s_data.Variant, 'E-FQ'), :);
                q_ok = all(abs(efq_stress.Median_Q11_Fade - 0.05) < 1e-5) && ...
                       all(abs(efq_stress.Median_Q22_Fade - 0.002) < 1e-5);
                       
                if v_schema_ok && s_schema_ok && q_ok
                    FINAL_10 = true;
                else
                    fprintf('\n[!] SMOKE VALIDATION SCHEMA/VALUE MISMATCH\n');
                end
            end
        catch ME
            fprintf('\n[!] SMOKE VALIDATION FAILED: %s\n', ME.message);
        end
    end
    
    % --- Evaluate Admission Gates ---
    fprintf('\n=== PILOT ADMISSION GATES ===\n');
    cfg = paper2_config('quick');
    
    FINAL_2 = strcmp(cfg.final_tracker_variant, 'E-FQ');
    FINAL_3 = (cfg.c2_frozen == true && abs(cfg.c2 - 1/50) < 1e-6);
    FINAL_4 = isequal(cfg.final_Q, diag([0.05, 0.002])); % also tested in unit test history
    FINAL_5 = (cfg.frontend.use_trm == false);
    FINAL_6 = (cfg.equalizer.enabled == false && cfg.equalizer.adopted == false);
    
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
        fprintf('\nROUND8_1_INTEGRITY_PASS\n');
        fprintf('FINAL_ARCHITECTURE_FROZEN\n');
        fprintf('PILOT_READY_FOR_200MC\n');
        fprintf('PILOT_NOT_RUN\n');
        
        % Write manifest
        manifest_file = fullfile('results', 'final_freeze', 'final_freeze_manifest.txt');
        fid_m = fopen(manifest_file, 'w');
        fprintf(fid_m, 'freeze_basis_sha = 21eacc7e9393c889b40dd3cbba6edd7eb478cff4\n');
        fprintf(fid_m, 'generated_from_worktree = Round-8.1\n');
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
        fprintf(fid_m, 'pilot SNR range = -16:-10\n');
        fprintf(fid_m, 'stress SNR = 15 dB\n');
        fprintf(fid_m, 'pilot MC = 200\n');
        fprintf(fid_m, 'paper MC = 3000\n');
        fclose(fid_m);
    else
        fprintf('\nPILOT_BLOCKED\n');
    end
end
