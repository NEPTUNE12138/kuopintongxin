# PAPER 2 CODE ALIGNMENT AUDIT

| Paper claim | Code implementation | Experiment | Result file | Status |
|---|---|---|---|---|
| Modulation is DBPSK/DSSS | `generate_paper2_tx_signal.m`, differential decoding | `test_signal_model.m` | N/A | VERIFIED |
| State model is DLL delay/drift | `hvb_akf_delay_tracker.m` | `test_hvb_tracker.m` | N/A | VERIFIED |
| Early–Late measurement | `run_paper2_receiver_variant.m` (delta spacing) | `main_WUWNET_Paper_Validation.m` | `raw_results.mat` | VERIFIED |
| Hybrid TRM (CFAR+ACF) | `extract_cir_hybrid.m` | `generate_paper_trm_ablation.m` | `Fig_TRM_Ablation.png` | IMPLEMENTED — EFFICACY REJECTED |
| OS-CFAR | `os_cfar_1d.m` | `test_hybrid_cir_extraction.m` | N/A | UNIT SEMANTICS VERIFIED — NOT A PRIMARY CONTRIBUTION |
| HFM ACF floor | `extract_cir_hybrid.m` | `generate_paper_trm_ablation.m` | `Fig_TRM_Ablation.png` | IMPLEMENTED — EFFICACY REJECTED |
| Reliability metric ($m_k$) | `run_paper2_receiver_variant.m` | `main_WUWNET_Paper_Stress.m` | `stress_test_results.mat` | VERIFIED |
| VB coordinate-ascent | `hvb_akf_delay_tracker.m` (inner loop) | `test_hvb_tracker.m` | N/A | VERIFIED |
| Fixed c2 heteroscedastic penalty | `hvb_akf_delay_tracker.m` | `plot_sensitivity_c2.m` | `Fig_Sensitivity_c2.png` | VERIFIED |
| Structural Q (diag truncation) | `hvb_akf_delay_tracker.m` | `test_hvb_tracker.m` | N/A | VERIFIED |
| Final publication variants IAE / VB-FQ / E-FQ | N/A | N/A | N/A | FROZEN FOR PILOT |
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

## Final Publication Architecture & Parameters
- Bellhop local-cluster model: VERIFIED
- TRM primary contribution: REJECTED
- Common MMSE equalizer: REJECTED / NOT ADOPTED
- Adaptive-Q E-CAL: REJECTED
- E-FQ fixed-Q architecture: HELD-OUT CONFIRMED
- Final front-end: HFM coarse synchronization only
- Final Q: diag([0.05,0.002]) FROZEN
- Kcal: 8 FROZEN
- c2: 1/50 FROZEN
- Pilot SNR range: -16:-10 dB FROZEN
- Dynamic stress SNR: 15 dB FROZEN
- Final publication variants: IAE / VB-FQ / E-FQ
- Pilot: READY ONLY IF corrected FINAL-1..10 pass
- Paper: NOT RUN

*Status: FROZEN FOR PILOT*

*Note: The SyncFailRate metric reflects post-acquisition receiver processing failure rate (ReceiverFailRate), as the coarse synchronizer does not use a calibrated detector threshold.*

*Archival Note: Round-7 RMS-delay-spread column was input-channel RDS; not used in adoption gates.*

## Unimplemented / Rejected Claims
- 2D SNR-Delay Dynamic Routing (Explicitly removed)
- Dynamic Gradient $c_{2,k}$ (Explicitly removed)
- Pilot Mode Code Rate (Implicit, simplified away for validation)
