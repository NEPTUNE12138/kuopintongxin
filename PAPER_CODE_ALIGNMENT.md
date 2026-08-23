# PAPER 2 CODE ALIGNMENT AUDIT

| Paper claim | Code implementation | Experiment | Result file | Status |
|---|---|---|---|---|
| Modulation is DBPSK/DSSS | `generate_paper2_tx_signal.m`, differential decoding | `test_signal_model.m` | N/A | VERIFIED |
| State model is DLL delay/drift | `hvb_akf_delay_tracker.m` | `test_hvb_tracker.m` | N/A | VERIFIED |
| Early–Late measurement | `run_paper2_receiver_variant.m` (delta spacing) | `main_WUWNET_Paper_Validation.m` | `raw_results.mat` | VERIFIED |
| Hybrid TRM (CFAR+ACF) | `extract_cir_hybrid.m` | `generate_paper_trm_ablation.m` | `Fig_TRM_Ablation.png` | VERIFIED |
| OS-CFAR | `os_cfar_1d.m` | `test_hybrid_cir_extraction.m` | N/A | VERIFIED |
| HFM ACF floor | `extract_cir_hybrid.m` | `generate_paper_trm_ablation.m` | `Fig_TRM_Ablation.png` | VERIFIED |
| Reliability metric ($m_k$) | `run_paper2_receiver_variant.m` | `main_WUWNET_Paper_Stress.m` | `stress_test_results.mat` | VERIFIED |
| VB coordinate-ascent | `hvb_akf_delay_tracker.m` (inner loop) | `test_hvb_tracker.m` | N/A | VERIFIED |
| Fixed c2 heteroscedastic penalty | `hvb_akf_delay_tracker.m` | `plot_sensitivity_c2.m` | `Fig_Sensitivity_c2.png` | VERIFIED |
| Structural Q (diag truncation) | `hvb_akf_delay_tracker.m` | `test_hvb_tracker.m` | N/A | VERIFIED |
| Variants A/B/C/D/E | `run_paper2_receiver_variant.m` | `main_WUWNET_Paper_Validation.m` | `ber_results.csv` | VERIFIED |
| Bellhop profiles (3 configs) | `paper2_config.m` | `main_WUWNET_Paper_Validation.m` | `ber_results.csv` | VERIFIED |
| MC Count = 3000 | `paper2_config.m` (`paper` mode) | `main_WUWNET_Paper_Validation.m` | `raw_results.mat` | PARTIAL |
| BER calculated over total bits | `main_WUWNET_Paper_Validation.m` | `main_WUWNET_Paper_Validation.m` | `ber_results.csv` | VERIFIED |
| Runtime benchmark | `benchmark_paper2_receivers.m` | `benchmark_paper2_receivers.m` | CLI output | VERIFIED |

- [x] Phase 1: Project Skeleton & Utilities
- [x] Phase 2: Transmit Signal Generation & Sync
- [x] Phase 3: Bellhop Channel Loader
- [x] Phase 4: Receiver & Tracking Mechanics
- [x] Phase 5: Tracking & Synchronization Wrappers
- [x] Phase 6: Unit Tests & Assertions
- [x] Phase 7: Simulation Pipeline (Integration)
- [x] Phase 8: Results & Documentation

## Status of Execution
- `quick` Pipeline (Gate verification & Diagnostics): **COMPLETE**
- `pilot` Pipeline (200 MC): **PENDING**
- `paper` Pipeline (3000 MC): **PENDING**

## Unimplemented / Rejected Claims
- 2D SNR-Delay Dynamic Routing (Explicitly removed)
- Dynamic Gradient $c_{2,k}$ (Explicitly removed)
- Pilot Mode Code Rate (Implicit, simplified away for validation)
