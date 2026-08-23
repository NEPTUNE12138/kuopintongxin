function test_pilot_result_schema()
% TEST_PILOT_RESULT_SCHEMA Checks expected 3x7x3=63 BER summary rows and 9 Stress rows on smoke output.
    val_file = fullfile('results', 'final_freeze', 'final_smoke_validation.csv');
    stress_file = fullfile('results', 'final_freeze', 'final_smoke_stress.csv');
    
    if exist(val_file, 'file')
        t = readtable(val_file, 'VariableNamingRule', 'preserve');
        assert(height(t) == 63, 'BER summary must have exactly 63 rows');
    end
    
    if exist(stress_file, 'file')
        t = readtable(stress_file, 'VariableNamingRule', 'preserve');
        assert(height(t) == 9, 'Stress summary must have exactly 9 rows');
    end
    
    disp('test_pilot_result_schema passed.');
end
