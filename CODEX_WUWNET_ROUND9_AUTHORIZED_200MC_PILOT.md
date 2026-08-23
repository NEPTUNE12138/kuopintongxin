# WUWNET Paper 2 — Round-9 Authorized 200-MC Pilot

Repository:
`NEPTUNE12138/kuopintongxin`

Authorized start commit:
`2d88efc37e3c0333a8ee99ade388cca43c01d902`

STATUS ENTERING ROUND-9:

```text
ROUND-8.1 integrity review: ACCEPTED
FINAL ARCHITECTURE: FROZEN
200-MC PILOT: AUTHORIZED
3000-MC PAPER: NOT AUTHORIZED
```

This is the first authorized 200-MC Pilot.

This is NOT an algorithm-design round.

ABSOLUTELY DO NOT:
- change Q
- change c2
- change Kcal
- change reliability formula
- change VB recursion
- change Early/Late spacing
- change Bellhop cluster policy
- change Pilot SNR range
- change stress SNR
- revive TRM
- revive MMSE equalization
- search seeds
- drop bad profiles/SNRs
- rerun only favorable conditions
- tune anything after seeing Pilot results
- run 3000-MC Paper mode

---

# 0. Frozen receiver

The final receiver is:

```text
Bellhop-derived local arrival cluster
-> full channel convolution
-> HFM coarse synchronization
-> NO TRM
-> NO equalizer
-> DSSS Early/Late discriminator
-> relative reliability calibration
-> heteroscedastic VB measurement covariance
-> fixed-Q Bayesian delay/drift tracking
-> DBPSK differential detection
```

Frozen proposed tracker:

```text
E-FQ
```

Frozen settings:

```matlab
Q = diag([0.05, 0.002])
Kcal = 8
c2 = 1/50
q_adaptation_mode = 'fixed'
reliability.mode = 'relative_calibrated'
frontend.use_trm = false
equalizer.enabled = false
```

Frozen publication variants:

```text
IAE
VB-FQ
E-FQ
```

Frozen BER Pilot SNR:

```text
-16:-10 dB
```

Frozen dynamic stress:

```text
15 dB
Warp + 100-ms deep fade
all 3 Bellhop profiles
```

Pilot MC:

```text
200 trials per condition
```

Paper MC remains:

```text
3000
```

but must NOT be run in Round-9.

---

# 1. Minor non-scientific cleanup before Pilot

Do not change the algorithm.

## 1.1 PAPER_CODE_ALIGNMENT upper table

The upper table still contains the stale line:

```text
Variants A/B/C/D/E ... VERIFIED
```

Replace it with a final-publication line:

```text
Final publication variants IAE / VB-FQ / E-FQ
```

Status:

```text
FROZEN FOR PILOT
```

Legacy B/C/D/E may remain documented elsewhere as rejected-development variants.

Do not alter any result based on this documentation cleanup.

## 1.2 Receiver-failure terminology

The current HFM coarse synchronizer always chooses the maximum matched-filter peak and does not use a calibrated detector threshold.

Therefore Pilot results must NOT describe `SyncFailRate` as:
- acquisition miss probability
- packet detection probability
- false alarm probability

Use wording:

```text
ReceiverFailRate
```

or explicitly:

```text
post-acquisition receiver processing failure rate
```

If retaining legacy CSV column `SyncFailRate`, include this definition in the Pilot README/decision file.

No synchronization detector is to be added or tuned.

---

# 2. Pilot integrity gate BEFORE running 200 MC

Create:

```matlab
src/run_paper2_pilot_200mc.m
```

Before any Pilot simulation, assert:

```matlab
cfg = paper2_config('pilot');

cfg.final_architecture_frozen == true
cfg.final_tracker_variant == 'E-FQ'

cfg.c2_frozen == true
cfg.c2 == 1/50

cfg.final_Q == diag([0.05,0.002])
cfg.reliability.calibration_symbols == 8
cfg.hvb.q_adaptation_mode == 'fixed'

cfg.frontend.use_trm == false
cfg.trm_primary_contribution == false

cfg.equalizer.enabled == false
cfg.equalizer.adopted == false

cfg.snr_range == -16:1:-10
cfg.pilot_snr_range == -16:1:-10
cfg.stress_snr_db == 15

cfg.mc_trials_ber == 200
cfg.mc_trials_stress == 200
```

Run the full valid test suite from Round-8.1 first.

If any integrity test fails:

```text
PILOT_ABORTED_INTEGRITY_FAILURE
```

and terminate.

Do not partially run the Pilot.

---

# 3. Pilot BER experiment

Run final Validation with:

```matlab
mode = 'pilot'
SNR = -16:1:-10
MC = 200
Profiles = P1,P2,P3
Variants = IAE,VB-FQ,E-FQ
```

Use the same random realization for all variants within:

```text
Profile × SNR × trial
```

That means identical:
- bits
- selected Bellhop local cluster
- channel output
- AWGN
- HFM sync input

Only the tracker differs.

Do not change any seed rule after seeing results.

Required total BER receiver evaluations:

```text
3 profiles × 7 SNR × 3 variants × 200
= 12,600 variant evaluations
```

Save exact generated CSV and MAT paths.

---

# 4. Pilot dynamic Stress experiment

Run:

```matlab
mode = 'pilot'
SNR = 15 dB
MC = 200
Profiles = P1,P2,P3
Variants = IAE,VB-FQ,E-FQ
```

Physical scenario:

```text
continuous time warp
v0 = 0.5 m/s
velocity amplitude = 1.5 m/s
frequency = 0.2 Hz
phase = 0

100-ms Gaussian deep fade
same physical fade definition already frozen
```

Ground truth:
- `apply_paper2_time_warp`
- true symbol-center timing
- physical PRE/FADE/POST masks

Required stress receiver evaluations:

```text
3 profiles × 3 variants × 200
= 1,800 variant evaluations
```

Do not use frame thirds.

---

# 5. Preserve paired raw trial data

Pilot analysis must be PAIRED because all variants share the same trial realization.

BER MAT must preserve for every:

```text
Profile × SNR × Variant × Trial
```

at minimum:
- bit errors
- validity
- frame error

Stress MAT must preserve for every:

```text
Profile × Variant × Trial
```

at minimum:
- overall RMSE
- PRE RMSE
- FADE RMSE
- POST RMSE
- BER
- validity
- mean/median reliability telemetry
- K
- R_vb
- R_eff
- R_eff/R_vb
- Q11
- Q22

Do not only save aggregate CSV.

---

# 6. Add reliability telemetry needed for final mechanism evidence

The final Stress summary currently reports:
- K
- R_eff
- R_eff/R_vb
- Q

Also export for E-FQ and VB-FQ:

```text
Median_m_PRE
Median_m_FADE
Median_m_POST

Median_R_eff_R_vb_PRE
Median_R_eff_R_vb_FADE
Median_R_eff_R_vb_POST

Median_K_PRE
Median_K_FADE
Median_K_POST
```

If raw receiver metadata already exposes:
- rho_raw
- rho_relative

also save their PRE/FADE/POST medians.

This is telemetry only.
Do NOT change the filter.

The key expected mechanism is:

```text
fade -> lower relative reliability
     -> larger R_eff/R_vb
     -> smaller K
```

---

# 7. Pilot statistical analysis

Create:

```matlab
src/analyze_paper2_pilot.m
```

Use fixed analysis rules defined BEFORE inspecting Pilot results.

## 7.1 Tracking ratios

For every profile compute:

```text
median RMSE E-FQ / IAE
median RMSE E-FQ / VB-FQ
```

for:
- Overall
- PRE
- FADE
- POST

## 7.2 Paired bootstrap

For paired per-trial RMSE differences:

```text
D_IAE = RMSE_EFQ - RMSE_IAE
D_VB  = RMSE_EFQ - RMSE_VBFQ
```

Use:

```text
10,000 paired bootstrap resamples
fixed bootstrap seed = 20260909
```

Report:
- median paired difference
- 95% percentile CI
- paired win rate:
  fraction of valid paired trials where E-FQ RMSE is lower

Do this for Overall and FADE RMSE.

Do not use an unpaired test.

## 7.3 BER/FER transition metrics

For each Profile × Variant, on the frozen integer grid define:

```text
SNR50 =
lowest SNR in [-16,-10] for which FER_Overall <= 0.50

SNR05 =
lowest SNR in [-16,-10] for which FER_Overall <= 0.05
```

Lower/more negative is better.

Do not interpolate for the primary threshold table.
Optional interpolation may be supplemental only.

Also report BER_Valid and FER_Overall at every SNR.

## 7.4 Uncertainty

Use:
- existing Wilson 95% CI for BER_Valid
- Wilson 95% CI for FER_Overall as well

Add FER Wilson interval if not currently exported.

For FER_Overall, N = total frames = 200.

---

# 8. PREDECLARED Pilot-to-Paper gates

These gates are fixed BEFORE seeing the 200-MC results.

They determine whether 3000-MC Paper execution is scientifically justified.

## PILOT-1 — numerical validity

For every Pilot BER condition:

```text
ReceiverFailRate <= 0.05
```

For Stress:

```text
valid trial rate >= 0.95
```

If not:
```text
PILOT_FAIL_NUMERICAL_VALIDITY
```

Do not hide failed trials.

---

## PILOT-2 — primary dynamic tracking benefit vs IAE

For ALL three profiles at 15-dB Warp+Fade:

```text
median Overall_RMSE(E-FQ) <= median Overall_RMSE(IAE)
```

and:

```text
median Fade_RMSE(E-FQ) <= median Fade_RMSE(IAE)
```

No profile may violate either inequality.

Additionally:

```text
median across profiles of Overall RMSE ratio E-FQ/IAE <= 0.90
```

This means the central effect must be at least about 10% on the primary stress metric.

---

## PILOT-3 — reliability contribution beyond fixed-Q VB

For ALL three profiles:

```text
median Fade_RMSE(E-FQ) <= median Fade_RMSE(VB-FQ)
```

Across the three profiles:

```text
median Fade_RMSE ratio E-FQ/VB-FQ < 1.00
```

For paired bootstrap:

```text
upper 95% CI of median paired FADE difference (E-FQ - VB-FQ) < 0
```

must hold for at least 2 of 3 profiles.

If point estimates improve but bootstrap support is weaker:
classify as:

```text
RELIABILITY_INCREMENTAL_BENEFIT_WEAK
```

Do not falsely call it significant.

---

## PILOT-4 — mechanism consistency

For E-FQ in EACH profile:

```text
Median_m_FADE < Median_m_PRE
Median_R_eff_R_vb_FADE > Median_R_eff_R_vb_PRE
Median_K_FADE < Median_K_PRE
```

and:

```text
Median_Q11 == 0.05
Median_Q22 == 0.002
```

for the whole experiment.

This is required to support the mechanism claim.

---

## PILOT-5 — communication non-inferiority

E-FQ is primarily a tracking contribution.
It does NOT have to beat IAE BER at every low-SNR point.

For EACH profile:

```text
SNR50_EFQ <= SNR50_IAE + 1 dB
SNR05_EFQ <= SNR05_IAE + 1 dB
```

That is the predeclared communication non-inferiority margin.

Also:

```text
at -10 dB:
FER_Overall_EFQ <= 0.05
ReceiverFailRate_EFQ <= 0.05
```

for all profiles.

Do not alter this gate if individual BER points look unfavorable.

---

## PILOT-6 — no hidden front-end contamination

Pilot run metadata must prove:

```text
TRM = false
equalizer = false
publication variants only = IAE / VB-FQ / E-FQ
Q fixed
c2 fixed
SNR grid fixed
stress SNR fixed
```

---

# 9. Pilot decision classes

## PASS

If PILOT-1 through PILOT-6 all pass:

```text
PILOT_200MC_PASS
PAPER_3000MC_READY
PAPER_NOT_RUN
```

Do not automatically run Paper.

## TRACKING PASS / BER NON-INFERIORITY FAIL

If tracking/mechanism gates pass but PILOT-5 fails:

```text
PILOT_TRACKING_PASS_COMMUNICATION_GATE_FAIL
PAPER_BLOCKED_PENDING_SCIENTIFIC_REVIEW
```

Do NOT retune the tracker.

This would mean the paper may need to focus more narrowly on timing tracking rather than communication BER.

## RELIABILITY ABLATION FAIL

If E-FQ does not outperform VB-FQ on the predeclared reliability contribution gate:

```text
PILOT_RELIABILITY_INCREMENTAL_GATE_FAIL
```

Do NOT change c2.

The final method story would need reassessment before Paper mode.

## PRIMARY TRACKING FAIL

If PILOT-2 fails:

```text
PILOT_PRIMARY_TRACKING_GATE_FAIL
PAPER_BLOCKED
```

No 3000-MC run.

---

# 10. Pilot outputs

Create:

```text
results/pilot_review/
```

Required files:

```text
pilot_ber_summary.csv
pilot_stress_summary.csv
pilot_tracking_paired_bootstrap.csv
pilot_transition_thresholds.csv
pilot_mechanism_table.csv
pilot_gate_report.txt
pilot_manifest.txt
pilot_raw_index.txt
```

Do not replace the raw `.mat` files from the underlying Pilot runs.
Reference their exact paths in `pilot_raw_index.txt`.

---

# 11. pilot_ber_summary.csv

Required columns:

```text
Profile
SNR_dB
Variant
Trials_Total
Trials_Valid
ReceiverFailCount
ReceiverFailRate
BitErrors_Valid
Bits_Valid
BER_Valid
BER_Wilson_Lower
BER_Wilson_Upper
FrameErrors_Valid
FER_Valid
FrameErrors_Overall
FER_Overall
FER_Wilson_Lower
FER_Wilson_Upper
```

If source files use legacy `SyncFailRate`, map it to `ReceiverFailRate` in this final review table.

---

# 12. pilot_stress_summary.csv

Required:

```text
Profile
Variant
Trials_Total
Trials_Valid
ValidRate
ReceiverFailRate
BER_Valid
FER_Overall

RMSE_Overall_Median
RMSE_PRE_Median
RMSE_FADE_Median
RMSE_POST_Median

RMSE_Overall_P10
RMSE_Overall_P90
RMSE_FADE_P10
RMSE_FADE_P90

Median_m_PRE
Median_m_FADE
Median_m_POST

Median_Reff_Rvb_PRE
Median_Reff_Rvb_FADE
Median_Reff_Rvb_POST

Median_K_PRE
Median_K_FADE
Median_K_POST

Median_Q11
Median_Q22
```

---

# 13. pilot_tracking_paired_bootstrap.csv

For each profile and comparison:

```text
E-FQ vs IAE
E-FQ vs VB-FQ
```

Metric:
```text
Overall_RMSE
Fade_RMSE
```

Columns:

```text
Profile
Comparison
Metric
N_Paired
Median_Difference
CI95_Lower
CI95_Upper
WinRate_EFQ
Median_Ratio
```

Difference convention:

```text
E-FQ - comparator
```

Negative is better.

---

# 14. pilot_transition_thresholds.csv

Columns:

```text
Profile
Variant
SNR50
SNR05
```

Also compute:

```text
Delta_SNR50_EFQ_minus_IAE
Delta_SNR05_EFQ_minus_IAE
```

in the decision report.

---

# 15. Reproducibility manifest

`pilot_manifest.txt`:

```text
pilot_basis_sha = 2d88efc37e3c0333a8ee99ade388cca43c01d902

final tracker = E-FQ
Q = [0.05,0.002]
Kcal = 8
c2 = 0.02

TRM = disabled
equalizer = disabled

channel model = bellhop_local_cluster
cluster gap = 0.05 s

BER SNR range = -16:-10 dB
BER MC = 200

stress SNR = 15 dB
stress MC = 200

warp v0 = 0.5 m/s
warp amp = 1.5 m/s
warp freq = 0.2 Hz
fade = 100-ms Gaussian deep fade

publication variants = IAE, VB-FQ, E-FQ

paper MC = 3000
paper run = NOT RUN
```

---

# 16. Pipeline safety

Do NOT simply remove all safety stops from `run_paper2_full_pipeline`.

Prefer a dedicated authorized Pilot entry:

```matlab
run_paper2_pilot_200mc
```

The existing general pipeline may remain blocked for `paper`.

After Pilot completes, it must stop.

Never call:

```matlab
main_WUWNET_Paper_Validation('paper')
main_WUWNET_Paper_Stress('paper')
run_paper2_full_pipeline('paper')
```

---

# 17. Required tests

Add:

### test_pilot_config_exact
Checks exact frozen Pilot settings.

### test_pilot_variant_fairness
Checks shared waveform/noise/sync and variant set.

### test_pilot_result_schema
Checks expected 3 × 7 × 3 = 63 BER summary rows and 9 Stress rows.

### test_pilot_raw_pairing
Checks trial index/seeds align across variants.

### test_pilot_no_parameter_mutation
Snapshot frozen config before Pilot and verify unchanged after Pilot.

### test_pilot_no_paper_execution
Ensure Pilot runner cannot launch Paper mode.

---

# 18. Important scientific interpretation

Do not panic if E-FQ is not the best BER method at every point.

The primary hypothesis is:

```text
reliability-calibrated fixed-Q Bayesian timing tracking
improves delay tracking robustness under nonstationary timing and fading
without materially degrading communication operating thresholds.
```

Therefore:
- tracking RMSE = primary
- reliability mechanism = primary explanatory evidence
- BER / FER = secondary end-to-end communication evidence

Do NOT rewrite the hypothesis after seeing results.

---

# HARD STOP AFTER PILOT

When 200-MC results are complete:

```text
STOP
```

Do not launch 3000-MC.

Do not change any parameter.

Commit the Pilot results and report to ChatGPT.

---

# REQUIRED FINAL REPORT

## Git
- Pilot basis SHA
- Pilot result commit SHA
- changed files

## Integrity
- frozen architecture unchanged: yes/no
- Q unchanged: yes/no
- c2 unchanged: yes/no
- Kcal unchanged: yes/no
- TRM disabled: yes/no
- EQ disabled: yes/no
- SNR range exact: yes/no
- stress exact: yes/no

## BER
Per profile:
- IAE SNR50 / SNR05
- VB-FQ SNR50 / SNR05
- E-FQ SNR50 / SNR05
- E-FQ minus IAE threshold deltas

## Tracking
Per profile:
- IAE overall/fade RMSE
- VB-FQ overall/fade RMSE
- E-FQ overall/fade RMSE
- E-FQ/IAE ratios
- E-FQ/VB-FQ ratios

## Paired bootstrap
All required CIs and win rates.

## Mechanism
PRE/FADE/POST:
- m
- R_eff/R_vb
- K
- Q

## Pilot gates
PILOT-1 through PILOT-6:
PASS / FAIL with numbers.

## Final decision
Exactly one:

```text
PILOT_200MC_PASS
PAPER_3000MC_READY
PAPER_NOT_RUN
```

or one of the predefined failure classifications.

Final line:

```text
WAITING FOR SCIENTIFIC REVIEW BEFORE 3000-MC PAPER RUN.
```
