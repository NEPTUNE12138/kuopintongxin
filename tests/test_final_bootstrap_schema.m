function test_final_bootstrap_schema()
    T_boot = readtable(fullfile('results', 'paper_review', 'final_bootstrap_table.csv'));
    
    assert(height(T_boot) == 12, 'Bootstrap table must have exactly 12 rows');
    
    comparisons = unique(T_boot.Comparison);
    assert(length(comparisons) == 2, 'Must have 2 comparisons');
    assert(ismember('E-FQ vs IAE', comparisons) && ismember('E-FQ vs VB-FQ', comparisons), 'Comparisons mismatch');
    
    metrics = unique(T_boot.Metric);
    assert(length(metrics) == 2, 'Must have 2 metrics');
    assert(ismember('Overall_RMSE', metrics) && ismember('Fade_RMSE', metrics), 'Metrics mismatch');
    
    assert(all(T_boot.N_Paired == 3000 | T_boot.N_Paired == 2999 | T_boot.N_Paired == 2998), 'N_Paired must be close to 3000 (valid masks)');
    
    assert(all(~isnan(T_boot.CI95_Lower)) && all(~isnan(T_boot.CI95_Upper)), 'CI values must be finite');
    
    disp('test_final_bootstrap_schema passed.');
end
