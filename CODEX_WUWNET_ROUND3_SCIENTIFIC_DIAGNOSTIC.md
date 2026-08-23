# WUWNET Paper 2 — Round-3 Scientific Diagnostic & Reliability Calibration

Repository:
`NEPTUNE12138/kuopintongxin`

Baseline commit to start from:
`ac0c7e6f7ede3e06ec9a860eb342b9406a8b2d6f`

This round is NOT a paper-mode run and NOT a curve-beautification round.

Primary goals:
1. Determine why Proposed Variant E has worse dynamic tracking RMSE than C/D.
2. Determine whether the heteroscedastic reliability penalty or the VB covariance recursion is responsible.
3. Quantify whether Hybrid TRM actually differs from pure OS-CFAR and whether it improves focusing.
4. Remove confounding from the current c2 sensitivity experiment.
5. Locate the real BER waterfall before any 200-MC Pilot.

DO NOT run 200-MC Pilot.
DO NOT run 3000-MC Paper mode.
DO NOT edit manuscript performance claims.
DO NOT choose parameters simply because they make E look better.
DO NOT use `find_killer_seed.m` or any seed-search/cherry-picking workflow.

---

## 0. Preserve the current verified engineering baseline

Do not break the following already-passing gates:

- 31-chip bipolar m-sequence
- 6 samples/chip
- true HFM
- analytic-passband TX/RX
- explicit Bellhop loader
- A/B/C/D/E receiver architecture
- noiseless A-E BER = 0
- Bellhop high-SNR smoke test
- Early/Late sign test
- ground-truth timing trajectory
- BER all-fail -> NaN
- Variant-D covariance stability
- Q-freeze test
- deterministic seeds
- full Quick pipeline execution

Run all existing Gate tests after every algorithmic change.

---

# PART A — Centralize impairment generation

## A1. Add `lib/apply_paper2_time_warp.m`

Create a single physical timing-warp helper used by:

- `main_WUWNET_Paper_Stress.m`
- `plot_sensitivity_c2.m`
- new diagnostic scripts

Suggested interface:

```matlab
[sig_warp, warp_meta] = apply_paper2_time_warp(sig_in, cfg, warp_cfg)
```

`warp_cfg` contains:

```matlab
v0_mps
velocity_amp_mps
velocity_freq_hz
phase_rad
```

Implementation must be physically consistent with the current Stress code:

```matlab
t = (0:length(sig_in)-1)/cfg.fs;
v = v0 + A_v*sin(2*pi*f_v*t + phi);
alpha = 1 + v/c_sound;
t_src = cumtrapz(t, alpha);
t_src = t_src - t_src(1);
sig_warp = interp1(t, sig_in, t_src, 'linear', 0);

epsilon_true_samples = (t - t_src)*cfg.fs;
```

Return at least:

```matlab
warp_meta.t
warp_meta.velocity_mps
warp_meta.alpha
warp_meta.t_src
warp_meta.epsilon_true_samples
```

Do not use the current sensitivity formula:

```matlab
t_src = t + d_amp*sin(...)/1500
```

because it does not share the Stress physical model.

---

# PART B — Diagnose HVB before changing it

## B1. Add diagnostic flags without changing default Paper-2 behavior

Extend config with diagnostic-safe flags:

```matlab
cfg.hvb.use_heteroscedastic = true;
cfg.hvb.use_q_freeze = true;
cfg.reliability.mode = 'absolute';  % current baseline behavior
cfg.reliability.calibration_symbols = 8;
```

Default `paper2_config()` must reproduce the current Variant E exactly.

Modify `hvb_akf_delay_tracker.m` only enough to support:

### Mode E-original
Current full HVB:
- VB covariance recursion
- heteroscedastic Lambda
- Q-freeze

### Diagnostic mode E-VB-only
- same VB covariance recursion
- force `Lambda_k = 1`
- disable reliability-based Q-freeze
- no other changes

Do NOT add E-VB-only to the publication A/B/C/D/E list.
It is a diagnostic-only configuration.

---

## B2. Add `src/diagnose_hvb_failure.m`

Run exactly four predefined scenarios using Profile P1.

Use 50 MC trials per scenario.
Use deterministic diagnostic seeds distinct from Pilot/Paper seeds.

Scenarios:

### S0 Static
- Bellhop multipath
- SNR = 15 dB
- no time warp
- no artificial fade

### S1 Warp only
- Bellhop multipath
- SNR = 15 dB
- physical time warp
- no fade

Use the same warp parameters as current Stress:
```matlab
v0 = 0.5;
A_v = 1.5;
f_v = 0.2;
```

### S2 Fade only
- Bellhop multipath
- SNR = 15 dB
- no time warp
- current Gaussian deep fade

### S3 Warp + Fade
- Bellhop multipath
- SNR = 15 dB
- physical time warp
- current Gaussian deep fade

For each scenario run:

- C
- E-original
- E-VB-only

All three must use:
- identical payload
- identical channel
- identical noise
- identical warp
- identical fade
- identical sync output

---

## B3. Define actual fade masks, not thirds of the frame

The current Stress labels fixed first/middle/final thirds as pre/fade/post.
Replace this for diagnostics and later Stress.

Sample `fade_env` at payload symbol centers.

Define:

```matlab
fade_mask_symbols = fade_env_at_symbol_centers < 0.5;
```

Define:
- PRE = symbols before first fade-mask symbol
- FADE = fade_mask_symbols
- POST = symbols after last fade-mask symbol

If no fade:
use the full payload as NORMAL and do not fabricate fade zones.

Export mask thresholds in metadata.

---

## B4. Export reliability/covariance distributions

For E-original and E-VB-only, export per scenario and per phase:

For each of:

```text
rho
m_reliability
Lambda
R_vb
R_eff
R_eff / R_vb
K_gain(1,:)
Q11
Q22
abs(delay innovation)
tracking error
```

calculate:

```text
mean
median
P10
P90
```

Also export:

```text
tracking RMSE
BER
valid-trial rate
```

Files:

```text
results/diagnostic/hvb_diagnostic_summary.csv
results/diagnostic/hvb_diagnostic_raw.mat
results/diagnostic/Fig_HVB_Diagnostic.png
```

The figure should show ensemble medians with percentile bands, not a hand-picked seed.

---

# PART C — Decision logic: identify the actual failure mechanism

After Part B, print an automatic diagnostic classification.

## C1. Reliability-scale suspect

Flag:

```text
RELIABILITY_SCALE_SUSPECT
```

if in S0 or the non-fade portion of S1:

```matlab
median(m_reliability) < 0.8
```

OR

```matlab
median(R_eff ./ R_vb) > 1.5
```

Normal non-faded operation should not continuously trigger a large heteroscedastic penalty.

## C2. VB-recursion suspect

Flag:

```text
VB_RECURSION_SUSPECT
```

if E-VB-only is still materially worse than C under S1:

```matlab
RMSE_E_VB_only > 1.5 * RMSE_C
```

or if `R_vb` strongly grows in S1 despite high reliability and no fade.

## C3. Heteroscedastic penalty suspect

Flag:

```text
HETERO_PENALTY_SUSPECT
```

if:

- E-VB-only is close to C,
- but E-original is much worse than E-VB-only.

Print all ratios explicitly.
Do not hide an unfavorable classification.

---

# PART D — Only if reliability scaling is the main suspect, create a calibrated candidate

Do NOT overwrite the baseline E immediately.

Create a candidate mode:

```text
E-CAL
```

for diagnostics only.

## D1. Relative reliability calibration

Keep the existing raw normalized prompt correlation:

```matlab
rho_raw_k = abs(corr_p) / sqrt(Eseg * Ecode + eps);
```

For the first:

```matlab
Kcal = cfg.reliability.calibration_symbols; % default 8
```

valid payload symbols, collect `rho_raw`.

After Kcal:

```matlab
rho_ref = median(rho_raw(1:Kcal));
rho_rel = min(1, rho_raw / max(rho_ref, eps));
m_rel = sqrt(rho_rel_k * rho_rel_prev);
```

During the calibration symbols:

```matlab
Lambda = 1;
do not reliability-freeze Q;
```

After calibration:
use `m_rel` for Lambda and Q-freeze.

Preserve raw values separately:

```matlab
meta.rho_raw
meta.rho_ref
meta.rho_relative
meta.m_reliability
```

Do not silently rename raw rho to calibrated rho.

### Scientific interpretation

The calibrated metric must represent:

> instantaneous correlation quality relative to the nominal correlation supported by the current multipath channel,

not absolute ideal-code similarity.

---

## D2. Re-run the four 50-MC scenarios

Compare:

- C
- E-original
- E-VB-only
- E-CAL

E-CAL is allowed to become the new proposed candidate ONLY if:

1. non-fade median `m` >= 0.8;
2. non-fade median `R_eff/R_vb` <= 1.5;
3. fade median `m` is lower than non-fade median `m`;
4. fade median `R_eff/R_vb` is larger than non-fade value;
5. tracking remains correlated with ground truth;
6. E-CAL does not suffer the current ~4x dynamic-RMSE degradation;
7. no existing noiseless/smoke Gate breaks.

Do not require E-CAL to beat C in every single metric.
Do require the mechanism to behave as claimed.

If these criteria fail:
do NOT replace E.
Stop and report the diagnostic data.

---

# PART E — Do not tune c2 yet; first fix the sensitivity experiment

The current sensitivity script confounds SNR and dynamic severity because:

```matlab
snr_range = [0,15];
doppler_severity = [0.1,0.5];
d_amp = doppler_severity(si);
```

Thus SNR and dynamics change together.

Refactor `plot_sensitivity_c2.m` into a factorial design.

Use independent dimensions:

```matlab
snr_set = [0, 15];
velocity_amp_set = [0.5, 1.5];
```

This gives four conditions:

```text
0 dB, 0.5 m/s
0 dB, 1.5 m/s
15 dB, 0.5 m/s
15 dB, 1.5 m/s
```

Use the shared `apply_paper2_time_warp.m`.

Use exact ground-truth timing RMSE.

Candidate grid must include exact current c2:

```matlab
c2_grid = unique(sort([logspace(-3,1,10), cfg.c2]));
```

Quick diagnostic only:
20 trials per condition/c2.

Export:

```text
results/diagnostic/c2_factorial_sensitivity.csv
```

Columns:

```text
SNR_dB
VelocityAmp_mps
c2
ValidTrials
MeanRMSE
MedianRMSE
StdError
```

Do NOT automatically change cfg.c2 after this experiment.
Do NOT label any value “chosen” yet.

At the end print:

- best c2 per condition
- rank of current c2 per condition
- average rank of current c2
- whether one c2 is near-optimal across all four conditions

We will select/freeze c2 only after review.

---

# PART F — Quantify Hybrid TRM contribution

Add:

`src/diagnose_trm_contribution.m`

Do not use BER alone.

For each of all three Bellhop profiles, and SNR:

```matlab
[-10, 0]
```

run 30 deterministic preamble/noise trials.

For each trial:

1. load real `h_true = load_bellhop_cir(...)`;
2. generate actual HFM;
3. pass HFM through `h_true`;
4. add controlled noise;
5. matched filter;
6. build:
   - OS-only extraction
   - Hybrid extraction
7. retain:
   - OS mask
   - Hybrid mask
   - gamma_os
   - gamma_acf
   - gamma_hybrid

Add to `extract_cir_hybrid.m` metadata:

```matlab
meta.os_mask
meta.hybrid_mask
meta.os_path_count
meta.hybrid_path_count
meta.acf_floor_active_fraction
```

where:

```matlab
acf_floor_active_fraction = mean(gamma_acf > gamma_os);
```

Compute mask Jaccard similarity:

```matlab
intersection / union
```

---

## F1. Focusing metrics must use the TRUE Bellhop CIR

Construct:

```matlab
q_os = conj(fliplr(h_os));
q_hyb = conj(fliplr(h_hybrid));
normalize both by norm.
```

Then:

```matlab
h_eq_os  = conv(h_true, q_os);
h_eq_hyb = conv(h_true, q_hyb);
```

Do NOT compute the main focusing evidence as:

```matlab
conv(h_ext, q)
```

because that evaluates the estimate against itself.

For:
- original h_true
- h_eq_os
- h_eq_hyb

compute:

### RMS delay spread
Energy-normalized second central moment of delay.

### Peak concentration ratio
Energy within ±1 chip around the strongest peak / total energy.

### PSLR
Strongest peak power divided by largest sidelobe power outside ±1 chip.

Also export:
- path count
- Jaccard
- ACF floor active fraction

Save:

```text
results/diagnostic/trm_diagnostic.csv
results/diagnostic/Fig_TRM_Diagnostic.png
```

---

## F2. Do not tune kappa to create an artificial difference

Add current implicit default explicitly to config:

```matlab
cfg.kappa_side = 1.5;
```

Do NOT search over kappa in this round.

Automatic classification:

If across all profiles/SNRs:

```text
median Jaccard > 0.95
```

and Hybrid vs OS focusing metrics differ by less than 2%:

print:

```text
HYBRID_ACF_CONSTRAINT_MOSTLY_INACTIVE
```

Do not try to force a difference.

If the ACF floor becomes active primarily at low SNR and improves focusing:
print that objectively.

---

# PART G — Locate the real BER waterfall

Only after the diagnostic candidate is fixed for this round, add:

`src/quick_snr_boundary_scan.m`

Use 20 MC only.

SNR:

```matlab
-22:1:-8
```

All 3 Bellhop profiles.
At minimum compare:
- C
- current proposed candidate (E-original or E-CAL depending diagnostic outcome)

Optionally A/B if runtime is acceptable.

Use strict aggregate BER statistics already implemented.

Do not interpolate through exact BER=0.

For target BER=1e-3 report a bracket:

Example:

```text
P1 E: crossing bracket [-18, -17] dB
```

If target is already met at the lowest SNR:

```text
crossing < -22 dB
```

If not met at highest:
```text
crossing > -8 dB
```

Save:

```text
results/diagnostic/snr_boundary_scan.csv
results/diagnostic/snr_boundary_summary.md
```

---

# PART H — Fix provenance/housekeeping

1. Make these functions mode-aware and cwd-independent:
   - `generate_paper_trm_ablation`
   - `plot_sensitivity_c2`
   - `benchmark_paper2_receivers`
   - `export_paper_parameters`

2. Remove `../lib` and `../config` path assumptions.
Use `mfilename('fullpath')` + project root.

3. Refactor:

```matlab
export_paper_parameters(mode)
```

Do NOT always load `paper2_config('paper')`.

For quick/diagnostic output:
do not generate artifacts that look like final Paper-mode evidence.

4. In `PAPER_CODE_ALIGNMENT.md`:
   - quick pipeline = COMPLETE
   - pilot = PENDING
   - paper = PENDING
   - `MC Count = 3000` must be PARTIAL until actual 3000-MC output exists
   - final performance claims remain PARTIAL

5. `find_killer_seed.m` must not be called anywhere in the Paper-2 pipeline.
Add a header:
```text
LEGACY/DIAGNOSTIC ONLY — NOT PUBLICATION EVIDENCE
```
or move it to a clearly named legacy folder without changing historical files.

---

# PART I — Required new tests

Add:

## `tests/test_reliability_calibration.m`

For synthetic nominal correlation:
- calibrated nominal m should approach 1;
- a forced 50% prompt-correlation drop must reduce m;
- Lambda must increase after the drop.

## `tests/test_time_warp_helper.m`

Verify:
- zero velocity -> epsilon_true approximately zero;
- constant positive velocity produces monotonic timing drift;
- finite outputs, correct length.

## `tests/test_trm_true_cir_metrics.m`

Verify:
- metric functions operate on actual h_true;
- delta channel gives near-zero RMS delay spread;
- convolution metric code is finite and normalized.

Do not weaken existing tests.

---

# PART J — STOP CONDITIONS

After completing this round:

Run:
1. all existing Gate tests;
2. the 3 new tests;
3. `diagnose_hvb_failure`;
4. factorial c2 diagnostic;
5. TRM diagnostic;
6. low-SNR boundary scan.

DO NOT run:

```matlab
run_paper2_full_pipeline('pilot')
```

DO NOT run:

```matlab
run_paper2_full_pipeline('paper')
```

---

# FINAL RESPONSE FORMAT

Return exactly these sections:

## 1. Git
- commit SHA
- changed files

## 2. Existing Gate tests
- PASS/FAIL

## 3. HVB diagnostic classification
For S0-S3:
- RMSE C
- RMSE E-original
- RMSE E-VB-only
- RMSE E-CAL if created
- normal/fade median rho
- median m
- median Lambda
- median R_vb
- median R_eff/R_vb
- median K

Then print flags:
- RELIABILITY_SCALE_SUSPECT yes/no
- VB_RECURSION_SUSPECT yes/no
- HETERO_PENALTY_SUSPECT yes/no

## 4. Reliability candidate decision
- Was E-CAL created?
- Did it pass all mechanism criteria?
- Was baseline E changed? (should remain no unless all criteria pass and change is explicitly documented)

## 5. c2 factorial diagnostic
- best c2 per each of 4 conditions
- current 1/50 rank per condition
- no automatic parameter change

## 6. TRM diagnostic
Per profile/SNR:
- OS path count
- Hybrid path count
- Jaccard
- ACF floor active fraction
- RMS delay spread original/OS/Hybrid
- peak concentration original/OS/Hybrid
- PSLR original/OS/Hybrid
- classification

## 7. BER boundary scan
Per profile:
- target 1e-3 crossing bracket for C and proposed candidate

## 8. Alignment status
- Quick COMPLETE
- Pilot PENDING
- Paper PENDING

## 9. Final line
`PILOT NOT RUN — waiting for scientific review.`

If a diagnostic test shows the VB recursion itself is the main problem:
do NOT compensate by tuning c2.
Stop and report `VB_RECURSION_SUSPECT`.
