function test_final_smoke_artifact_paths()
% TEST_FINAL_SMOKE_ARTIFACT_PATHS Verify that smoke validation CSVs are files, not directories.
    
    val_dst = fullfile('results', 'final_freeze', 'final_smoke_validation.csv');
    stress_dst = fullfile('results', 'final_freeze', 'final_smoke_stress.csv');
    
    if exist(val_dst, 'dir')
        error('final_smoke_validation.csv is a directory! It must be a file.');
    end
    
    if exist(stress_dst, 'dir')
        error('final_smoke_stress.csv is a directory! It must be a file.');
    end
    
    disp('test_final_smoke_artifact_paths passed.');
end
