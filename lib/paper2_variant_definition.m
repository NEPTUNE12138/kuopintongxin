function variant_info = paper2_variant_definition(var_char)
% PAPER2_VARIANT_DEFINITION Returns definition of WUWNET Paper 2 variants
%   Variant A: No TRM + IAE-AKF
%   Variant B: OS-CFAR TRM + IAE-AKF
%   Variant C: Hybrid TRM + IAE-AKF
%   Variant D: Hybrid TRM + C-Gated IAE (Heuristic)
%   Variant E: Hybrid TRM + HVB-AKF (Proposed)

    variant_info = struct();
    variant_info.id = var_char;
    
    switch var_char
        case 'A'
            variant_info.name = 'A: No TRM + IAE-AKF';
            variant_info.uses_trm = false;
            variant_info.uses_hybrid = false;
            variant_info.uses_reliability = false;
            variant_info.uses_vb = false;
        case 'B'
            variant_info.name = 'B: OS-CFAR TRM + IAE-AKF';
            variant_info.uses_trm = true;
            variant_info.uses_hybrid = false;
            variant_info.uses_reliability = false;
            variant_info.uses_vb = false;
        case 'C'
            variant_info.name = 'C: Hybrid TRM + IAE-AKF';
            variant_info.uses_trm = true;
            variant_info.uses_hybrid = true;
            variant_info.uses_reliability = false;
            variant_info.uses_vb = false;
        case 'D'
            variant_info.name = 'D: Hybrid TRM + C-Gated IAE';
            variant_info.uses_trm = true;
            variant_info.uses_hybrid = true;
            variant_info.uses_reliability = true;
            variant_info.uses_vb = false;
        case 'E'
            variant_info.name = 'E: Proposed Hybrid TRM + HVB-AKF';
            variant_info.uses_trm = true;
            variant_info.uses_hybrid = true;
            variant_info.uses_reliability = true;
            variant_info.uses_vb = true;
        case 'E-VB-only'
            variant_info.name = 'E-VB-only: Diagnostic Variant';
            variant_info.uses_trm = true;
            variant_info.uses_hybrid = true;
            variant_info.uses_reliability = true;
            variant_info.uses_vb = true;
        case 'E-CAL'
            variant_info.name = 'E-CAL: Diagnostic Calibrated Variant';
            variant_info.uses_trm = true;
            variant_info.uses_hybrid = true;
            variant_info.uses_reliability = true;
            variant_info.uses_vb = true;
        case 'E-FQ'
            variant_info.name = 'E-FQ: Proposed Fixed-Q Variant';
            variant_info.uses_trm = true;
            variant_info.uses_hybrid = true;
            variant_info.uses_reliability = true;
            variant_info.uses_vb = true;
        case 'VB-FQ'
            variant_info.name = 'VB-FQ: Ablation Fixed-Q Variant';
            variant_info.uses_trm = true;
            variant_info.uses_hybrid = true;
            variant_info.uses_reliability = false;
            variant_info.uses_vb = true;
        otherwise
            error('Unknown variant ID: %s. Valid options: A, B, C, D, E, E-VB-only, E-CAL, E-FQ, VB-FQ', var_char);
    end
end
