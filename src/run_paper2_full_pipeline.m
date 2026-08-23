% run_paper2_full_pipeline.m
% WUWNET Paper 2 Master Pipeline
clc; clear; close all;
addpath('../lib');
addpath('../config');

fprintf('=========================================\n');
fprintf('  WUWNET Paper 2 Full Pipeline Execution \n');
fprintf('=========================================\n\n');

try
    fprintf('1. Checking Dependencies & Bellhop Channels...\n');
    cfg = paper2_config('quick');
    for i = 1:size(cfg.channels, 1)
        if ~exist(cfg.channels{i, 1}, 'file')
            error('Missing channel file: %s', cfg.channels{i, 1});
        end
    end
    
    fprintf('2. Running Unit Tests...\n');
    cd('../tests');
    test_signal_model;
    test_hybrid_cir_extraction;
    test_hvb_tracker;
    test_variant_consistency;
    cd('../src');
    
    fprintf('3. Exporting Parameters...\n');
    export_paper_parameters;
    
    fprintf('4. Final 3-Channel BER Simulation...\n');
    % Uncomment to run real simulation
    % main_WUWNET_Paper_Validation; 
    fprintf(' (Skipped here to prevent blocking, run manually if needed)\n');
    
    fprintf('5. Extreme Fading Stress Test...\n');
    % main_WUWNET_Paper_Stress;
    fprintf(' (Skipped here to prevent blocking, run manually if needed)\n');
    
    fprintf('6. TRM Real-Data Ablation...\n');
    generate_paper_trm_ablation;
    
    fprintf('7. C2 Sensitivity...\n');
    plot_sensitivity_c2;
    
    fprintf('8. Runtime Benchmark...\n');
    benchmark_paper2_receivers;
    
    fprintf('\n=========================================\n');
    fprintf(' Pipeline Executed Successfully!\n');
    fprintf('=========================================\n');
catch ME
    fprintf('\n=========================================\n');
    fprintf(' PIPELINE FAILED: %s\n', ME.message);
    fprintf('=========================================\n');
end
