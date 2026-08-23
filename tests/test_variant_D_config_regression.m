function test_variant_D_config_regression()
% TEST_VARIANT_D_CONFIG_REGRESSION Ensures Variant D parameters do not drift.

    cfg = paper2_config('quick');
    assert(cfg.var_D_A == 50, 'Variant D parameter A drifted! Expected 50, got %f', cfg.var_D_A);
    assert(cfg.var_D_b == 8, 'Variant D parameter b drifted! Expected 8, got %f', cfg.var_D_b);
    fprintf('test_variant_D_config_regression passed.\n');
end
