function test_candidate_no_trm_semantics()
    fprintf('Running test_candidate_no_trm_semantics...\n');
    
    vd_efq = paper2_variant_definition('E-FQ');
    assert(~vd_efq.uses_trm, 'E-FQ must have uses_trm=false');
    assert(~vd_efq.uses_hybrid, 'E-FQ must have uses_hybrid=false');
    
    vd_vbfq = paper2_variant_definition('VB-FQ');
    assert(~vd_vbfq.uses_trm, 'VB-FQ must have uses_trm=false');
    assert(~vd_vbfq.uses_hybrid, 'VB-FQ must have uses_hybrid=false');
    
    fprintf('test_candidate_no_trm_semantics passed.\n');
end
