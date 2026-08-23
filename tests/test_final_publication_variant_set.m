function test_final_publication_variant_set()
    fprintf('Running test_final_publication_variant_set...\n');
    
    % Read main_WUWNET_Paper_Validation to check variants definition
    val_file = fullfile(fileparts(mfilename('fullpath')), '..', 'src', 'main_WUWNET_Paper_Validation.m');
    content = fileread(val_file);
    
    has_variants = contains(content, 'variants = {''A'', ''VB-FQ'', ''E-FQ''}');
    assert(has_variants, 'main_WUWNET_Paper_Validation must use exactly {''A'', ''VB-FQ'', ''E-FQ''}');
    
    has_labels = contains(content, 'csv_labels = {''IAE'', ''VB-FQ'', ''E-FQ''}');
    assert(has_labels, 'main_WUWNET_Paper_Validation must use csv_labels {''IAE'', ''VB-FQ'', ''E-FQ''}');
    
    fprintf('test_final_publication_variant_set passed.\n');
end
