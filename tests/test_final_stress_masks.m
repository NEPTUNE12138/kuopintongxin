function test_final_stress_masks()
    fprintf('Running test_final_stress_masks...\n');
    
    % Read main_WUWNET_Paper_Stress to verify fade mask bounds
    stress_file = fullfile(fileparts(mfilename('fullpath')), '..', 'src', 'main_WUWNET_Paper_Stress.m');
    content = fileread(stress_file);
    
    has_fmask = contains(content, 'fmask = fade_env_at_centers < 0.5;');
    assert(has_fmask, 'Stress script must use fmask based on fade envelope');
    
    has_pre = contains(content, 'pre_idx = 1:(first_fade-1);');
    assert(has_pre, 'Stress script must physically isolate PRE region');
    
    fprintf('test_final_stress_masks passed.\n');
end
