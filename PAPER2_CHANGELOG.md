# WUWNET Paper 2 Changelog

## Modified/New Files
- **Configurations**: `config/paper2_config.m`
- **Algorithms**: `lib/os_cfar_1d.m`, `lib/extract_cir_hybrid.m`, `lib/hvb_akf_delay_tracker.m`, `lib/run_paper2_receiver_variant.m`, `lib/generate_paper2_tx_signal.m`
- **Tests**: `tests/test_signal_model.m`, `tests/test_hybrid_cir_extraction.m`, `tests/test_hvb_tracker.m`, `tests/test_variant_consistency.m`
- **Simulations**: `src/main_WUWNET_Paper_Validation.m`, `src/main_WUWNET_Paper_Stress.m`, `src/generate_paper_trm_ablation.m`, `src/plot_sensitivity_c2.m`, `src/benchmark_paper2_receivers.m`
- **Utilities**: `src/export_paper_parameters.m`, `src/extract_paper_metrics.m`, `src/run_paper2_full_pipeline.m`

## Removed Claims
- Dynamic Gradient $c_{2,k}$: Removed in favor of fixed $c_2 = 1/50$ as requested by the major revision prompt.
- 2D SNR-Delay Dynamic Routing: The bypass logic was stripped out from the BER generation code.
- DQPSK: Removed entirely. The signal model explicitly enforces DBPSK/DSSS.
- Carrier-Phase PLL: The tracker focuses purely on the DLL phase and drift (time delay state).

## Parameter Changes
- Fixed length m-sequence dynamically read from `data/mseq.mat`.
- OS-CFAR parameters strictly defined with a fallback analytical calculation for the scale factor.
- Monte Carlo trials adjustable via config modes (`quick` = 20, `paper` = 3000).

## Known Limitations
- The analytical scaling factor in `os_cfar_1d.m` uses a crude numerical/analytical approximation which might slightly deviate from a perfect exponential-noise $P_{fa}$ root but is robust against `NaN`.
- Benchmarks are executed via MATLAB's `tic`/`toc` rather than dedicated C/ARM timing due to lack of physical hardware setup.
