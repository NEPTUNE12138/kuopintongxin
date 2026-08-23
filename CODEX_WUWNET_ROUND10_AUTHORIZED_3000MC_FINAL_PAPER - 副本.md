# WUWNet Paper 2 — Round-10 Authorized 3000-MC Final Paper Run

Repository:
`NEPTUNE12138/kuopintongxin`

Authorized start commit:
`01521c6d3bc2f3d9455b87e01898869fb635b37a`

STATUS ENTERING ROUND-10:

```text
Round-9.1 mechanism telemetry repair: VERIFIED
Round-9 Stress deterministic reproduction: EXACT
PILOT-1 through PILOT-6: ALL PASS
FINAL ARCHITECTURE: FROZEN
3000-MC PAPER RUN: AUTHORIZED
```

This is the FINAL large-Monte-Carlo execution round.

It is NOT an algorithm-design round.

ABSOLUTELY DO NOT:
- change Q
- change c2
- change Kcal
- change reliability formula
- change VB recursion
- change Early/Late spacing
- change Bellhop local-cluster policy
- change BER SNR grid
- change stress SNR
- change warp/fade model
- revive TRM
- revive equalization
- add a learned model
- tune thresholds based on results
- search seeds
- drop unfavorable profiles/SNR points
- rerun only favorable cells
- change the publication variant set
- overwrite Pilot evidence
- edit manuscript prose

If the 3000-MC result differs from Pilot, report the difference.
Do not tune the method to restore the Pilot result.

---

# 0. Frozen final method

Final receiver chain:

```text
Bellhop-derived local arrival cluster
-> full channel convolution
-> HFM coarse synchronization
-> NO TRM
-> NO equalizer
-> DSSS Early/Late discriminator
-> relative packet-calibrated reliability
-> heteroscedastic VB measurement covariance
-> fixed-Q Bayesian delay/drift tracking
-> DBPSK differential detection
```

Final proposed tracker:

```text
E-FQ
```

Frozen parameters:

```matlab
Q = diag([0.05, 0.002])
Kcal = 8
c2 = 1/50
q_adaptation_mode = 'fixed'
reliability.mode = 'relative_calibrated'

frontend.use_trm = false
trm_primary_contribution = false

equalizer.enabled = false
equalizer.adopted = false

bellhop_cluster_gap_s = 0.05
channel_model = 'bellhop_local_cluster'
```

Final publication variants:

```text
IAE
VB-FQ
E-FQ
```

Final BER grid:

```text
-16:-10 dB
```

Final dynamic stress:

```text
15 dB
continuous time warp
v0 = 0.5 m/s
velocity amplitude = 1.5 m/s
frequency = 0.2 Hz
phase = 0
100-ms Gaussian deep fade
```

Final MC:

```text
BER: 3000 per Profile × SNR × Variant
Stress: 3000 per Profile × Variant
```

---

# 1. Pre-Paper integrity block

Create:

```matlab
src/run_paper2_paper_3000mc.m
```

Before any final simulation, assert exactly:

```matlab
cfg = paper2_config('paper');

cfg.final_architecture_frozen == true;
strcmp(cfg.final_tracker_variant,'E-FQ');

cfg.c2_frozen == true;
abs(cfg.c2 - 1/50) < 1e-12;

isequal(cfg.final_Q, diag([0.05,0.002]));
cfg.reliability.calibration_symbols == 8;
strcmp(cfg.reliability.mode,'relative_calibrated');
strcmp(cfg.hvb.q_adaptation_mode,'fixed');

cfg.frontend.use_trm == false;
cfg.trm_primary_contribution == false;

cfg.equalizer.enabled == false;
cfg.equalizer.adopted == false;

isequal(cfg.snr_range,-16:1:-10);
isequal(cfg.pilot_snr_range,-16:1:-10);

cfg.stress_snr_db == 15;

cfg.mc_trials_ber == 3000;
cfg.mc_trials_stress == 3000;
```

Also verify Git basis:

```text
expected basis SHA =
01521c6d3bc2f3d9455b87e01898869fb635b37a
```

Do not require the current working-tree commit to equal the basis if only
Round-10 execution plumbing has been added, but store both:
- paper_basis_sha
- execution_worktree_sha

If any frozen scientific field differs:

```text
PAPER_ABORTED_FROZEN_CONFIG_MISMATCH
```

Stop before simulation.

---

# 2. Strengthen two integrity tests before the long run

This is test-only plumbing. Do NOT change the algorithm.

## 2.1 Mechanism telemetry test must not vacuously pass

Current `test_pilot_mechanism_telemetry_complete.m` catches `Paper2:SyncFail`
and may finish without assertion.

Fix it so a sync/receiver failure FAILS the test.

The test must:
- obtain one successful deterministic E-FQ trial;
- assert required telemetry vector lengths;
- build non-empty PRE/FADE/POST masks;
- compute phase summaries;
- assert every required phase summary is finite.

No catch-and-ignore behavior.

## 2.2 Factor PILOT/PAPER mechanism gate into a helper

Create:

```matlab
lib/evaluate_mechanism_gate.m
```

Inputs:
- phase telemetry structure
- expected Q

Return:
```text
pass
status
details
```

Fail closed if any required field is missing/NaN/Inf.

Use the same helper in final Paper analysis.

Update:
```text
test_pilot4_fail_closed_on_nan
```
to call the real helper, not duplicate the gate logic.

This prevents code/test divergence.

---

# 3. Preserve all existing Pilot evidence

DO NOT overwrite or delete:

```text
results/pilot/
results/pilot_review/
```

Round-10 outputs go only to:

```text
results/paper/
results/paper_review/
results/paper_figures/
```

Pilot remains the predeclared model-selection/admission evidence.

Paper is confirmatory large-MC evidence.

---

# 4. Deterministic seed policy

Use the existing deterministic seed equations unchanged.

For each:
```text
Profile × SNR × trial
```
all publication variants share:
- bits
- Bellhop local cluster
- AWGN
- coarse-sync input

For each:
```text
Profile × stress trial
```
all variants share:
- bits
- Bellhop local cluster
- time warp
- fade envelope
- AWGN
- coarse-sync input

Do not change seeds from Round-9/Pilot.

3000-MC extends the trial index from:
```text
1:200
```
to:
```text
1:3000
```
under the same rule.

---

# 5. Checkpoint/resume for the long run

The final run is large:

BER:
```text
3 profiles × 7 SNR × 3 variants × 3000
= 189,000 receiver evaluations
```

Stress:
```text
3 profiles × 3 variants × 3000
= 27,000 receiver evaluations
```

Total:
```text
216,000 receiver evaluations
```

Implement deterministic checkpoint/resume WITHOUT changing the scientific run.

Create:

```text
results/paper/checkpoints/
```

Checkpoint BER after each completed:

```text
Profile × SNR
```

Checkpoint Stress after each completed:

```text
Profile
```

Checkpoint must store:
- completed cell identifiers
- raw trial arrays
- exact cfg snapshot
- seed-policy version/string
- paper_basis_sha

On resume:
- verify cfg snapshot is identical;
- verify basis SHA;
- verify seed policy;
- skip ONLY cells marked fully complete;
- never skip partial trials unless the partial array contains explicit completed trial indices and can be resumed exactly.

If mismatch:

```text
PAPER_RESUME_INTEGRITY_FAILURE
```

Do not resume.

Once all data are complete, consolidate into final MAT files.

Do NOT allow checkpointing to alter random streams.

---

# 6. Final 3000-MC BER/FER run

Execute final Validation:

```text
mode = paper
Profiles = P1/P2/P3
SNR = -16:-10 dB
Variants = IAE/VB-FQ/E-FQ
MC = 3000
```

Output raw arrays preserving:

```text
Profile × SNR × Variant × Trial
```

At minimum:
- bit-error count
- valid/receiver-failure flag
- frame-error flag
- seed/trial index reproducibility information

Required statistics per cell:

```text
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

Keep the terminology:

```text
ReceiverFailRate =
post-acquisition receiver processing / tracking failure rate,
NOT a calibrated acquisition miss probability.
```

---

# 7. Final 3000-MC dynamic Stress run

Execute:

```text
mode = paper
Profiles = P1/P2/P3
Variants = IAE/VB-FQ/E-FQ
SNR = 15 dB
MC = 3000
```

Same frozen:
- time warp
- fade
- true symbol-center ground truth
- PRE/FADE/POST physical masks

Save per-trial:

```text
rmse_overall
rmse_pre
rmse_fade
rmse_post

raw bit errors
valid flag

m_pre
m_fade
m_post

Reff_Rvb_pre
Reff_Rvb_fade
Reff_Rvb_post

K_pre
K_fade
K_post

Q11_pre
Q11_fade
Q11_post

Q22_pre
Q22_fade
Q22_post
```

For E-FQ every valid trial must have finite mechanism fields.

---

# 8. Final statistical analysis

Create:

```matlab
src/analyze_paper2_paper.m
```

No threshold may be tuned here.

## 8.1 BER/FER thresholds

Using the same frozen integer-grid definitions:

```text
SNR50 =
lowest SNR for which FER_Overall <= 0.50

SNR05 =
lowest SNR for which FER_Overall <= 0.05
```

No interpolation for the primary table.

Report:
```text
Delta_SNR50 = E-FQ - IAE
Delta_SNR05 = E-FQ - IAE
```

More negative is better.

## 8.2 Paired tracking effects

For every profile, comparison:

```text
E-FQ vs IAE
E-FQ vs VB-FQ
```

metrics:

```text
Overall RMSE
Fade RMSE
```

Use paired trial arrays.

Report:
- median E-FQ
- median comparator
- median ratio
- median paired difference
- paired E-FQ win rate

## 8.3 Paired bootstrap

Use:

```text
10,000 paired bootstrap resamples
bootstrap seed = 20260909
```

Report 95% percentile CI for:
```text
median(E-FQ - comparator)
```

Negative is better.

Do not switch test/statistic after looking at the result.

## 8.4 Effect-size percentages

For descriptive reporting:

```text
Tracking reduction vs IAE =
100 * (1 - median(E-FQ)/median(IAE))

Reliability incremental reduction =
100 * (1 - median(E-FQ)/median(VB-FQ))
```

Compute for:
- Overall
- Fade

Do not label these as significance tests.

---

# 9. Mechanism evidence

For E-FQ, per profile report final 3000-MC medians:

```text
m_PRE
m_FADE
m_POST

R_eff/R_vb_PRE
R_eff/R_vb_FADE
R_eff/R_vb_POST

K_PRE
K_FADE
K_POST

Q11_PRE/FADE/POST
Q22_PRE/FADE/POST
```

Also report descriptive changes:

```text
m fade drop (%)
R-inflation increase (%)
K fade reduction (%)
```

Do not overclaim causality.

Supported wording if direction remains correct:

```text
Under the controlled fade, the relative DSSS reliability decreases,
the effective measurement covariance is inflated relative to the VB
baseline, and the delay-state gain decreases, while process covariance
remains fixed.
```

---

# 10. Final confirmatory gates

Use the SAME scientific criteria as the authorized Pilot.
Do not invent stricter or looser post-hoc thresholds.

## PAPER-1 — validity

For every BER condition:

```text
ReceiverFailRate <= 0.05
```

For Stress:

```text
ValidRate >= 0.95
```

## PAPER-2 — primary tracking

For every profile:

```text
median Overall_RMSE(E-FQ) <= median Overall_RMSE(IAE)
median Fade_RMSE(E-FQ)    <= median Fade_RMSE(IAE)
```

and across profiles:

```text
median Overall ratio E-FQ/IAE <= 0.90
```

## PAPER-3 — reliability contribution

For every profile:

```text
median Fade_RMSE(E-FQ) <= median Fade_RMSE(VB-FQ)
```

Across profiles:

```text
median Fade ratio E-FQ/VB-FQ < 1
```

Bootstrap:

```text
upper 95% CI of paired Fade difference E-FQ - VB-FQ < 0
```

for at least 2 of 3 profiles.

## PAPER-4 — mechanism

For E-FQ in every profile:

```text
m_FADE < m_PRE
R_eff/R_vb_FADE > R_eff/R_vb_PRE
K_FADE < K_PRE
Q11 = 0.05
Q22 = 0.002
```

Missing telemetry = FAIL.

Use:
```text
evaluate_mechanism_gate.m
```

## PAPER-5 — communication non-inferiority

For every profile:

```text
SNR50_EFQ <= SNR50_IAE + 1 dB
SNR05_EFQ <= SNR05_IAE + 1 dB
```

At -10 dB:

```text
FER_Overall_EFQ <= 0.05
ReceiverFailRate_EFQ <= 0.05
```

## PAPER-6 — frozen architecture

Verify:
- E-FQ frozen
- Q fixed
- c2 fixed
- Kcal fixed
- TRM off
- EQ off
- profile set fixed
- SNR grid fixed
- stress model fixed
- variant set fixed

If any PAPER gate fails:
report exactly which gate and values.

DO NOT tune anything.

---

# 11. Pilot-to-Paper consistency analysis

Create:

```text
results/paper_review/pilot_paper_consistency.csv
```

For each comparable metric report:

```text
Profile
Variant/Comparison
Metric
PilotValue
PaperValue
Difference
RelativeDifference
DirectionConsistent
```

Include:
- BER threshold SNR50/SNR05
- Overall RMSE medians
- Fade RMSE medians
- E-FQ/IAE ratios
- E-FQ/VB-FQ ratios
- mechanism directions

This is descriptive, not another selection gate.

If Paper differs materially from Pilot, report it rather than hiding it.

---

# 12. Final publication data tables

Create:

```text
results/paper_review/final_ber_table.csv
results/paper_review/final_threshold_table.csv
results/paper_review/final_tracking_table.csv
results/paper_review/final_bootstrap_table.csv
results/paper_review/final_mechanism_table.csv
results/paper_review/final_gate_report.txt
results/paper_review/final_manifest.txt
results/paper_review/final_raw_index.txt
```

`final_tracking_table.csv` must contain per profile/variant:

```text
N
ValidRate

Overall_RMSE_Median
Overall_RMSE_P10
Overall_RMSE_P90

PRE_RMSE_Median
FADE_RMSE_Median
POST_RMSE_Median

BER_Valid
FER_Overall
```

`final_bootstrap_table.csv`:

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
ReductionPercent
```

---

# 13. Publication figures

Create:

```text
results/paper_figures/
```

Generate source-data-backed figures only from final 3000-MC results.

## Fig A — BER vs SNR
One figure per profile OR one clear 3-profile composition.

Methods:
```text
IAE
VB-FQ
E-FQ
```

Use final Wilson intervals.

Do not hide zero BER.
If semilog requires display floor, distinguish visualization floor from actual zero value.

## Fig B — FER vs SNR
Same profiles/methods.
Show FER_Overall.

## Fig C — Dynamic tracking RMSE
Show for each profile:
```text
IAE
VB-FQ
E-FQ
```

for:
```text
Overall
Fade
```

Prefer medians with uncertainty or distribution summaries.

## Fig D — Reliability mechanism
For E-FQ:
PRE / FADE / POST for:
```text
m
R_eff/R_vb
K
```

Q may be shown in table/inset as fixed:
```text
Q11 = 0.05
Q22 = 0.002
```

## Fig E — Paired effect distribution
Optional but recommended:
paired per-trial:
```text
E-FQ - IAE
E-FQ - VB-FQ
```
for Fade RMSE, by profile.

Save for every final figure:
```text
.png
.pdf
.fig
source CSV
```

Use publication-readable labels.
Do not use rejected TRM/E-CAL variants in final figures.

---

# 14. Runtime / complexity characterization

Update or create a benchmark limited to:

```text
IAE
VB-FQ
E-FQ
```

Use a fixed representative packet and deterministic repeated timing.

Run enough repetitions for a stable median, e.g.:
```text
100
```

Report:
```text
median runtime per packet
P10/P90 runtime
relative runtime vs IAE
```

Do NOT make timing a scientific gate.

Do not benchmark legacy TRM as part of final method comparison.

Save:

```text
results/paper_review/final_runtime_table.csv
```

---

# 15. Final manifest

`final_manifest.txt` must record:

```text
paper_basis_sha = 01521c6d3bc2f3d9455b87e01898869fb635b37a
execution_worktree_sha = <actual pre-result commit if applicable>

final tracker = E-FQ
Q = [0.05,0.002]
Kcal = 8
c2 = 0.02

TRM = disabled
equalizer = disabled

channel model = bellhop_local_cluster
cluster gap = 0.05 s

profiles = P1,P2,P3
BER SNR = -16:-10 dB
BER MC = 3000

stress SNR = 15 dB
stress MC = 3000
warp v0 = 0.5 m/s
warp amp = 1.5 m/s
warp freq = 0.2 Hz
fade = 100-ms Gaussian deep fade

variants = IAE,VB-FQ,E-FQ

bootstrap resamples = 10000
bootstrap seed = 20260909
```

---

# 16. PAPER_CODE_ALIGNMENT.md

After the actual 3000-MC run:

If all final gates pass, update:

```text
Final publication variants: IAE / VB-FQ / E-FQ — FROZEN
200-MC Pilot: ALL PREDECLARED GATES PASS
3000-MC Paper: COMPLETE
Final large-MC gates: PASS
```

Change:
```text
MC Count = 3000 ... PARTIAL
```
to:
```text
VERIFIED
```
only after raw 3000-MC output exists.

Do NOT mark sea trials or full Bellhop multi-second multipath as verified.

---

# 17. Final scientific claims allowed from code/results

If the 3000-MC evidence supports them, archive these as supported conclusions
for ChatGPT manuscript drafting:

1. E-FQ improves dynamic delay-tracking RMSE relative to IAE under the
   controlled nonstationary warp+fade condition.

2. E-FQ improves fade-region tracking relative to VB-FQ, isolating an
   incremental benefit associated with the reliability-driven
   heteroscedastic measurement model beyond fixed-Q VB alone.

3. During fade, relative reliability decreases, effective measurement
   covariance inflation increases, and the delay-state gain decreases,
   while Q remains fixed.

4. Communication FER operating thresholds remain within the predeclared
   +1-dB non-inferiority margin relative to IAE.

5. Evidence is simulation-based using Bellhop-derived local arrival
   clusters, not sea-trial evidence.

Do NOT archive stronger claims than the numbers support.

---

# 18. Final decision classes

If PAPER-1 through PAPER-6 all pass:

```text
PAPER_3000MC_COMPLETE
FINAL_RESULTS_ACCEPTED
READY_FOR_MANUSCRIPT_AND_FIGURE_AUDIT
```

If one or more fail:

```text
PAPER_3000MC_COMPLETE
FINAL_RESULTS_GATE_FAIL
NO_PARAMETER_RETUNING
READY_FOR_SCIENTIFIC_REASSESSMENT
```

Either way:
- preserve all data;
- do not rerun selectively;
- do not tune.

---

# 19. Required final report from Codex

## Git
- paper basis SHA
- execution SHA
- result commit SHA
- changed files

## Execution
- BER completed cells / expected cells
- Stress completed cells / expected cells
- total receiver evaluations
- checkpoint/resume events, if any

## Integrity
- Q unchanged
- c2 unchanged
- Kcal unchanged
- TRM disabled
- EQ disabled
- SNR grid exact
- stress exact
- variants exact

## BER/FER
Per profile and method:
- SNR50
- SNR05
- -10 dB FER
- selected representative BER/FER points
- Wilson CIs

## Tracking
Per profile:
- IAE overall/fade
- VB-FQ overall/fade
- E-FQ overall/fade
- E-FQ/IAE ratio and reduction
- E-FQ/VB-FQ ratio and reduction

## Paired bootstrap
All final CI and win rates.

## Mechanism
For E-FQ P1/P2/P3:
- m PRE/FADE/POST
- R_eff/R_vb PRE/FADE/POST
- K PRE/FADE/POST
- Q11/Q22

## Pilot consistency
- main Pilot vs Paper differences
- whether effect directions reproduced

## Final gates
PAPER-1 through PAPER-6 with exact evidence.

## Final decision
Exactly one of:

```text
PAPER_3000MC_COMPLETE
FINAL_RESULTS_ACCEPTED
READY_FOR_MANUSCRIPT_AND_FIGURE_AUDIT
```

or:

```text
PAPER_3000MC_COMPLETE
FINAL_RESULTS_GATE_FAIL
NO_PARAMETER_RETUNING
READY_FOR_SCIENTIFIC_REASSESSMENT
```

Final line:

```text
NO FURTHER PARAMETER TUNING AUTHORIZED.
```
