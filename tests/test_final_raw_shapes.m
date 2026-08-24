function test_final_raw_shapes()
    ber_file = fullfile('results', 'paper', 'paper2_ber_validation_3000mc.mat');
    stress_file = fullfile('results', 'paper', 'paper2_stress_pilot_3000mc.mat');
    D_ber = load(ber_file);
    D_stress = load(stress_file);
    
    assert(isequal(size(D_ber.raw_errors), [3, 7, 3, 3000]), 'BER raw shape mismatch');
    
    for ch = 1:3
        for v = 1:3
            vc = strrep(D_ber.variants{v}, '-', '_');
            res = D_stress.results.(sprintf('CH%d', ch)).(vc);
            assert(length(res.valid) == 3000, 'Stress trial vector length must be 3000');
        end
    end
    disp('test_final_raw_shapes passed.');
end
