# WUWNET Paper 2 — Round-2 End-to-End Correction Prompt for Codex

你现在工作在项目仓库：

`NEPTUNE12138/kuopintongxin`

当前审计基准提交：

`fc160e6c1146fcf5ca0752fd9a06a440d97df93c`
`Major Revision WUWNET Paper 2: Architecture, Tests, and Validation`

本轮不是继续增加创新点，而是执行 **Round-2 End-to-End Correction**。

目标只有一个：

> 让 Paper 2 的新 pipeline 在信号模型、Bellhop CIR、同步、TRM、DLL、HVB-AKF、BER 统计和 Stress ground truth 上真正端到端一致。

在满足下面的强制测试之前，**禁止运行 3000 次 Paper Mode，禁止修改论文性能结论，禁止为了让 E 曲线胜出而调参数。**

---

# 0. 不可违反的原则

1. `最终项目文件/` 是 Paper 1 / 已发表工作历史归档。
   - 不修改其算法、实验参数、历史结果。
   - Paper 2 只修改根目录的新 `config/`, `lib/`, `src/`, `tests/`, `generated/`, `results_plots/WUWNET_Paper/` 及对应文档。

2. 不增加以下已经明确删除的 claim：
   - 2D SNR-Delay Dynamic Routing
   - Dynamic gradient `c_{2,k}`
   - DQPSK
   - carrier-phase PLL
   - 未实测的 ARM latency

3. 不修改 `WUWNET_Paper_Overleaf_EN.md` 或 ChatGPT 生成的论文 V2。
   - 论文全文由 ChatGPT 在最终实验冻结后修改。
   - 你只输出真实代码、测试、原始结果、图和自动指标。

4. 禁止：
   - killer seed
   - 手工改 BER
   - 手工画不存在的 routing/bypass
   - 把同步失败当成 BER=0
   - 从 MAT 文件中用 `fieldnames(...){1}` 猜信道
   - 把 LFM 叫 HFM
   - 把 discriminator RMS 叫 tracking RMSE
   - 用不存在的 ground truth 宣称 tracking error
   - 为了让 Proposed 好看而专门调 baseline 参数

---

# 1. 当前必须修复的 P0 问题

当前 GitHub 版本存在以下已审计问题，必须逐个修复：

## P0-1：DSSS 采样定义错误

当前：

- `cfg.N_pn = 6`
- 同时又有 `samples_per_chip = round(fs/fc) = 10`
- TX 对 PN 先 `repelem(..., samples_per_chip)`，再 `repmat(..., N_pn)`
- RX 却使用 `L_sym = len_SS * N_pn`

导致 TX/RX 每符号长度不一致。

### 必须修为唯一物理定义

Paper 2 继承原 WUWNET / Paper 1 的扩频采样定义：

- 31-chip m-sequence
- bipolar chips `{−1,+1}`
- **6 samples per chip**
- one spread symbol:
  `31 * 6 = 186 samples`

不要再使用：

`round(fs/fc)`

来定义 chip sampling。

建议配置统一成：

```matlab
cfg.code_index = 2;
cfg.samples_per_chip = 6;
cfg.code_length = 31; % verify from loaded mseq
cfg.symbol_samples = cfg.code_length * cfg.samples_per_chip;
```

删除或弃用含义重复的 `N_pn`。

如为兼容旧代码保留 `N_pn`：
必须令：

`cfg.N_pn = cfg.samples_per_chip`

且任何地方不得再额外乘一次。

---

# 2. M-sequence 必须恢复为原系统的 31-chip bipolar sequence

当前新代码错误地使用 `mseq_raw{1}`，原系统实际使用：

`mseq{2,1}`

并执行：

```matlab
mseq(mseq == 0) = -1;
```

### 强制要求

新增唯一加载函数：

`lib/load_paper2_mseq.m`

逻辑：

1. 从 `data/mseq.mat` 加载；
2. 若为 cell：
   - 使用 `cfg.code_index = 2`
3. 转 row vector；
4. `0 -> -1`
5. assert:
   - `length(mseq) == 31`
   - only contains `[-1,+1]`

任何 TX、RX、test 不允许自行重新读取 mseq。

---

# 3. 全系统必须选择一种一致的信号域，禁止 preamble 在通带而 data 在基带

当前 generator：

- preamble 在 3–7 kHz
- data_bb 在 0 Hz
- `cfg.fc = 5 kHz` 实际没有用于 payload

这在同一个 packet 中是错误的。

## 本轮统一使用：complex analytic passband simulation

这样既能保留 Bellhop complex arrival coefficients，又避免 real/complex 混乱。

### 3.1 DSSS payload

先生成 bipolar DBPSK/DSSS baseband：

```matlab
data_bb = kron(diff_syms, mseq_os);
```

其中：

```matlab
mseq_os = repelem(mseq, cfg.samples_per_chip);
```

每 differential spread symbol长度必须：

`31 * 6 = 186`

然后上变频：

```matlab
t_data = (0:length(data_bb)-1) / cfg.fs;
data_pb = data_bb .* exp(1j*2*pi*cfg.fc*t_data);
```

### 3.2 HFM preamble

不得使用 LFM approximation。

新增：

`lib/generate_hfm_preamble.m`

优先复用原：

`lib/syncsig.m`

中 `type == 2` 的真实 HFM 公式。

可以先生成 real HFM，再用：

```matlab
preamble = hilbert(preamble_real);
```

得到 analytic version。

必须 assert：

- center band around 3–7 kHz
- generator 不是 MATLAB `chirp(...linear...)`

### 3.3 packet

统一：

```text
[HFM preamble] + [guard] + [analytic-passband DBPSK/DSSS payload] + [guard]
```

所有 block 都处于同一采样率和通带/analytic-passband 表示中。

---

# 4. TX generator 必须输出 packet layout metadata

重构：

`lib/generate_paper2_tx_signal.m`

输出建议：

```matlab
[tx, data_bits, preamble, mseq, mseq_os, tx_meta]
```

`tx_meta` 至少包含：

- `num_data_bits`
- `num_diff_symbols` (= num_data_bits + 1 reference)
- `code_length`
- `samples_per_chip`
- `symbol_samples`
- `preamble_samples`
- `guard_samples`
- `payload_start_index`
- `payload_end_index`
- `fs`
- `fc`

强制 assert：

```matlab
length(payload) == (cfg.num_data_bits + 1) * cfg.symbol_samples
```

---

# 5. `paper2_config.m` 必须改为与当前工作目录无关

当前 config 混用：

- `data/mseq.mat`
- `../Bellhop2YS/...`

依赖 MATLAB 当前 cwd。

必须改为：

```matlab
this_file = mfilename('fullpath');
config_dir = fileparts(this_file);
project_root = fileparts(config_dir);
cfg.project_root = project_root;

cfg.mseq_path = fullfile(project_root,'data','mseq.mat');
cfg.bellhop_dir = fullfile(project_root,'Bellhop2YS');
cfg.results_dir = fullfile(project_root,'results_plots','WUWNET_Paper');
cfg.generated_dir = fullfile(project_root,'generated');
```

所有 channels 用绝对 `fullfile`。

任何主脚本和 tests 不得依赖 `cd(...)` 才能成功。

---

# 6. Bellhop 数据必须通过唯一 loader，禁止猜字段

新增：

`lib/load_bellhop_cir.m`

函数建议：

```matlab
[h, meta] = load_bellhop_cir(channel_file, fs)
```

必须明确读取：

- `delay_clean`
- 优先 `amp_clean_complex`
- 若不存在才使用 `amp_clean`
- 再不存在才允许使用 `amp_norm`

禁止：

```matlab
fieldnames(...){1}
```

禁止：

```matlab
first numeric vector
```

## 6.1 构造 FIR

```matlab
delay_rel = delay_clean - min(delay_clean);
delay_samples = round(delay_rel * fs) + 1;

h = zeros(1, max(delay_samples));

for p = 1:length(delay_samples)
    h(delay_samples(p)) = h(delay_samples(p)) + amp(p);
end
```

碰撞 tap 必须相加。

然后：

```matlab
h = h / (norm(h) + eps);
```

## 6.2 meta 必须保存

- channel filename
- amplitude field used
- number of arrivals
- absolute delays
- relative delays
- tap indices
- energy before normalization
- energy after normalization
- mean delay
- RMS delay spread
- max excess delay

所有：

- BER
- Stress
- TRM ablation
- sensitivity
- benchmark

统一调用这个 loader。

---

# 7. 修正 Bellhop 场景命名，不得继续误读文件名

Bellhop 原保存格式：

`channel_%dm_%dkm_%dm.mat`

参数是：

`Source_depth, range, Rcr_depth`

因此：

- `channel_15m_20km_34m`
  = Tx 15 m / range 20 km / Rx 34 m
- `channel_15m_20km_3467m`
  = Tx 15 m / range 20 km / Rx 3467 m
- `channel_100m_45km_110m`
  = Tx 100 m / range 45 km / Rx 110 m

在未找到与每个 MAT 一一对应的 bathymetry/environment 证据之前：

**禁止把 3467m profile 直接称为 “shallow-water slope”。**

本轮 config 用中性显示名：

- `Profile P1: Tx15m / 20km / Rx34m`
- `Profile P2: Tx15m / 20km / Rx3467m`
- `Profile P3: Tx100m / 45km / Rx110m`

同时更新：

`BELLHOP_REPRODUCIBILITY.md`

把已证实和未证实的信息分开。

---

# 8. 新增统一 coarse synchronization helper

新增：

`lib/coarse_sync_from_preamble.m`

建议使用 matched filter：

```matlab
mf = conv(rx, conj(fliplr(preamble)));
[~, peak_idx] = max(abs(mf));

preamble_start = peak_idx - length(preamble) + 1;
payload_start = preamble_start + length(preamble) + cfg.guard_samples;
```

输出：

- `peak_idx`
- `preamble_start`
- `payload_start`
- matched-filter output
- sync metric

任何 variant 不允许自己写一套 peak/pointer 公式。

---

# 9. Time-Reversal filter 统一构造与归一化

新增：

`lib/build_tr_filter.m`

输入 `h_ext`：

```matlab
q = conj(fliplr(h_ext));
q = q / (norm(q) + eps);
```

若 `h_ext` 全零：
返回明确失败状态，不得继续使用 zero filter。

使用 causal filtering 时明确记录：

```matlab
trm_group_delay = length(q) - 1;
```

payload pointer 修正：

```matlab
payload_start_focused = payload_start + trm_group_delay;
```

所有 variants 统一。

---

# 10. Variant A 必须是真正的 No-TRM

当前 A 虽然叫 No TRM，却仍然：

- 从 g_win 取一个主峰
- 构造 q_filter
- 应用 filter

这是错误消融。

修正：

### Variant A

```matlab
q_filter = 1;
sig_focused = sig_rx;
trm_group_delay = 0;
```

完全不执行 CIR extraction 和 TRM。

---

# 11. B/C/D/E 的 TRM 定义固定

最终：

### A
No TRM + IAE-AKF

### B
Order-statistic TRM + IAE-AKF

### C
Hybrid TRM + IAE-AKF

### D
Hybrid TRM + heuristic reliability-gated IAE-AKF

### E
Hybrid TRM + HVB-AKF

所有 variant metadata 中保存：

- `uses_trm`
- `uses_hybrid`
- `uses_reliability`
- `uses_vb`

新增：

`lib/paper2_variant_definition.m`

唯一返回定义。

所有 legend、audit 和 tests 从这里读取，不要手写五遍字符串。

---

# 12. Early–Late DLL 的单位和状态模型必须统一

Paper 2 state 定义：

```text
epsilon_k     = delay offset, samples
epsilonDot_k  = delay drift, samples/symbol
```

因此状态转移应使用：

```matlab
F = [1 1; 0 1];
```

不要再把 `symbol_dur` 秒直接乘到一个其实是 samples/symbol 的状态上。

如果你坚持使用 physical `samples/second`：
则必须全系统修改单位并在 tests 验证。

本轮推荐最小改动：

**使用 samples + samples/symbol。**

更新变量命名：

- `phase_off` -> `delay_offset_samples`
- `phase` -> `delay`
- `PLL` -> `DLL` / delay tracker

---

# 13. 新增 Early–Late 符号方向单元测试

新增：

`tests/test_early_late_sign.m`

构造：

- 无噪声
- 单一路径
- 已知 +1, +2, -1, -2 sample timing offset

验证：

1. Early–Late discriminator 符号与定义一致；
2. tracker 的 correction direction 正确；
3. positive injected delay 不会被滤波器越修越偏。

禁止凭经验假设 `(L-E)` 的符号一定正确。

---

# 14. Prompt reliability 必须归一化，不能直接依赖任意幅度尺度

当前：

```matlab
m_k = abs(u_k * conj(u_prev))
```

会受：

- channel amplitude
- TRM normalization
- passband gain
- filter gain

影响。

新增可靠度指标，建议使用 **normalized prompt correlation coefficient**：

```matlab
corr_p = sum(seg_P .* conj(mseq_os));
rho_k = abs(corr_p) / ...
        sqrt(sum(abs(seg_P).^2) * sum(abs(mseq_os).^2) + eps);

rho_k = min(max(rho_k,0),1);
```

跨符号可靠度：

```matlab
m_k = sqrt(rho_k * rho_prev);
```

于是：

```text
0 <= m_k <= 1
```

高可靠：

`m_k -> 1`

深衰落：

`m_k -> 0`

保存 raw prompt symbol `u_k` 用于 DBPSK decoding；
不要拿 normalized `rho_k` 代替数据软符号。

---

# 15. HVB heteroscedastic penalty 保留固定 c2

使用：

```matlab
Lambda_k = (1 + c2) / (m_k^2 + c2);
```

因为 `m_k ∈ [0,1]`：

- reliable `m=1 -> Lambda=1`
- fade `m=0 -> Lambda=(1+c2)/c2`

对于 `c2=1/50`：

`Lambda_max = 51`

这必须写进 unit test。

---

# 16. 修复 Q-freeze 永远不触发的问题

当前：

```matlab
Lambda_freeze = 100
```

但最大 Lambda 只有 51。

推荐不要用 arbitrary Lambda threshold，改成：

```matlab
cfg.q_freeze_reliability = 0.2;
```

若：

```matlab
m_k < cfg.q_freeze_reliability
```

则：

- freeze Q adaptation
- Q 本身仍用于 state prediction

若希望保留 Lambda threshold：
必须保证阈值在实际范围内，并在 unit test 触发。

优先使用 reliability threshold，更容易解释。

新增 test：

深衰落 `m_k ≈ 0` 时：
`Q_out == Q_prev`

---

# 17. Variant D 不能累乘污染基础 R

当前错误：

```matlab
R_k = R_k * penalty;
```

然后下一 symbol 在已放大的 R 上继续乘。

必须拆成：

```matlab
R_iae = persistent/base adaptive estimate
R_eff_D = R_iae * penalty_D
```

或者：

```matlab
R_eff_D = max(R_iae, R0 * penalty_D)
```

**R_eff_D 不允许写回 R_iae。**

Heuristic penalty 使用归一化 reliability `m_k` 后必须重新定义。

建议固定：

```matlab
penalty_D = 1 + 50 * exp(-8 * m_k);
```

性质：

- `m=0 -> 51`
- `m=1 -> ~1.017`

不要按 channel/SNR 调参数。

把 `A=50, b=8` 放 cfg 并记录。

新增 regression test：

高可靠连续 100 symbols 下：

- `R_iae` 不出现指数级增大
- D 的 `R_eff` 每个 symbol 都是瞬时值，不累乘

---

# 18. HVB inner loop 必须保持同一 prediction prior

保留当前正确思路：

每个 VB iteration 都从：

- `x_pred`
- `P_pred`

做 measurement update；

heteroscedastic penalty：

```matlab
R_eff = R_vb * Lambda
```

只影响 Kalman gain。

不得写回：

- alpha
- beta
- R_vb sufficient statistics

meta 至少保存：

- `R_vb`
- `R_eff`
- `K_gain`
- `rho_k`
- `m_k`
- `Lambda_k`
- `Q_diag`
- `x_pred`
- `x_post`

---

# 19. Receiver wrapper 必须输出真正 state history

`run_paper2_receiver_variant` 新输出建议：

```matlab
[decoded_bits, runtime, meta]
```

其中 `meta`：

- `status`
- `failure_reason`
- `num_processed_symbols`
- `u_prompt`
- `delay_measurement_z`
- `delay_est_samples`
- `delay_drift_est`
- `K_gain`
- `R_vb`
- `R_eff`
- `rho`
- `m_reliability`
- `Lambda`
- `Q_diag`
- sync metadata
- TRM metadata

不要再用：

`track_err_hist = z_k`

并把它叫 tracking error。

`z_k` 要明确叫：

`delay_measurement_history`

---

# 20. Stress Test 必须产生真实 code-timing ground truth

当前 Stress 只是：

```matlab
sig .* exp(1j phase)
```

这主要是相位扰动，不是 DLL timing drift。

必须改为 **time-axis warping / resampling**。

## 推荐物理实现

定义：

```matlab
v(t) = v0 + A_v*sin(2*pi*f_v*t + phi)
alpha(t) = 1 + v(t)/c_sound
```

receiver-time 对应 source-time：

```matlab
t_src = cumtrapz(t, alpha);
```

校正起点：

```matlab
t_src = t_src - t_src(1);
```

时间扭曲：

```matlab
sig_warp = interp1(t, sig_rx_clean, t_src, 'linear', 0);
```

ground truth：

```matlab
epsilon_true_samples = (t_src - t) * fs;
```

如果上述方向导致 injected positive delay 与 DLL sign 相反：
由 `test_early_late_sign` 验证并统一，不允许猜。

### Stress 还叠加 controlled deep fade

fade envelope 是独立 impairment。

必须保存：

- velocity history
- alpha history
- epsilon_true_samples
- fade envelope

---

# 21. 真正 tracking RMSE 的定义

每个 payload symbol 的 nominal sample center：

```matlab
symbol_center_idx(k)
```

从 `epsilon_true_samples` 抽样得到：

```matlab
epsilon_true_k
```

因为 coarse synchronization 可以吸收常量延迟：

比较相对轨迹：

```matlab
epsilon_true_rel = epsilon_true_k - epsilon_true_k(1);
epsilon_est_rel  = epsilon_est_k  - epsilon_est_k(1);
```

最终：

```matlab
error_k = epsilon_est_rel - epsilon_true_rel;
RMSE = sqrt(mean(error_k.^2));
```

单位：

- samples
- optionally convert to chips:
  `RMSE_chips = RMSE_samples / cfg.samples_per_chip`

论文后续只允许把这个叫：

**tracking RMSE**

Early–Late `z_k` 的 RMS 只能叫：

**discriminator RMS / measurement RMS**

---

# 22. Stress Test 不得静默把失败 trial 填成 0

当前数组预分配为 0，catch 后跳过，会导致 ensemble 平均被失败 trial 的零稀释。

必须：

- 使用 `NaN`
- 或维护 `valid_mask`

例如：

```matlab
track_error = nan(num_trials,num_symbols);
```

ensemble：

```matlab
mean(...,'omitnan')
```

同时保存：

`valid_trials`

若 valid rate 过低：
明确 warning / fail paper mode。

---

# 23. BER 主程序必须正确处理失败

当前：

```matlab
p = e ./ max(1,n)
```

导致：

`n=0 -> BER=0`

这是绝对禁止的。

修正：

```matlab
ber = nan(size(n));
valid = n > 0;
ber(valid) = e(valid)./n(valid);
```

Wilson CI：

仅 `n>0` 计算；
否则 `NaN`。

同时输出：

```matlab
sync_fail_rate = sync_fails / cfg.mc_trials;
```

再输出 frame-level：

```matlab
frame_error_count
frame_error_rate
```

定义：

- sync fail = frame fail
- 成功解码但 >=1 bit error = frame error

CSV 必须至少包含：

- Channel
- SNR
- Variant
- BER_valid
- CI_lower
- CI_upper
- valid_trials
- sync_fails
- sync_fail_rate
- frame_error_rate
- total_errors
- total_decoded_bits

绘图遇到 `NaN`：
不允许替换成 1e-6。

---

# 24. Unexpected exceptions 不得被当成“sync fail”

当前主程序：

```matlab
catch
  sync_fails += 1
end
```

这样代码 bug 会被伪装成信道失败。

修改：

receiver expected failures 返回：

```matlab
meta.status = 'SYNC_FAIL'
```

或自定义 error ID：

`Paper2:SyncFail`

仅这类可计入 sync fail。

其它 MATLAB exception：

**必须 rethrow**，使测试或 paper run 立即失败。

---

# 25. 新增最关键测试：Noiseless End-to-End

新增：

`tests/test_end_to_end_noiseless.m`

这是进入 Pilot 的硬门槛。

条件：

- deterministic fixed data bits
- true 31-chip bipolar m-sequence
- complex analytic-passband signal
- delta channel:
  `h = 1`
- no noise
- no Doppler
- no fade

运行 A/B/C/D/E。

强制：

```matlab
numel(decoded_bits) == numel(data_bits)
all(decoded_bits == data_bits)
BER == 0
```

五个 variant 必须全部通过。

若 Hybrid TRM 在 delta channel 下提取失败：
修 extraction/sync；
不得在 test 里绕过 TRM。

---

# 26. 新增 Bellhop loader regression test

`tests/test_bellhop_loader.m`

对三个真实 MAT：

assert:

- has `delay_clean`
- loader明确选择 amplitude field
- number of paths == length(delay_clean)
- FIR nonempty
- all finite
- `abs(norm(h)-1) < tolerance`
- RMS delay spread finite
- loaded h 不是 bounce-count / angle vector

禁止 generic field guessing。

---

# 27. 新增 end-to-end Bellhop smoke test

`tests/test_end_to_end_bellhop_smoke.m`

条件：

- 任选一个真实 Bellhop profile
- no added noise 或高 SNR
- fixed bits
- run A–E

不强制 A 必须 0 BER，因为 multipath可能严重。

但强制：

- B/C/D/E 不崩溃
- processed symbols > 90% payload
- decoded length合理
- no NaN/Inf
- sync metadata合理

若 E 在无噪声 Bellhop 下大量失败：
禁止进入 Pilot。

---

# 28. 新增 injected-delay ground-truth test

`tests/test_delay_tracking_ground_truth.m`

构造：

- delta/simple channel
- smooth known timing warp
- no deep fade
- high SNR

ground truth：

`epsilon_true_k`

验证 Proposed E：

- estimated delay trajectory 与 ground truth 正相关
- sign正确
- RMSE 有限
- 不能比“完全不修正”的 zero estimator 明显更差

若失败：
先修 DLL sign/state units，不准进入 BER pilot。

---

# 29. `test_hybrid_cir_extraction` 必须使用真正 HFM

当前 test 使用：

```matlab
chirp(...)
```

它是 LFM。

改为调用：

`generate_hfm_preamble.m`

新增 assert：

- hybrid threshold >= OS threshold
- main peak detected
- `gamma_acf > 0`
- `rho_side` 来自 exact preamble ACF
- edge cells 不因 training cell不足产生假 detection

---

# 30. OS-CFAR 边缘处理必须严格

当前 edge CUT training cell 数不足，但 alpha 仍按完整 N 标定。

推荐：

- 只在完整 training+guard window 内检测；
- 边缘 threshold = `Inf`;
- mask = false。

这样 Pfa scaling 与 N/k 一致。

如你决定支持 variable-N edges：
必须重新为 actual_N/actual_k 解 alpha。

---

# 31. TRM ablation 必须显示真实物理链路

`generate_paper_trm_ablation.m`：

必须调用：

- `generate_paper2_tx_signal`
- `load_bellhop_cir`
- actual HFM preamble
- actual matched filter
- `extract_cir_hybrid`

禁止复制一套 preamble 生成代码。

图至少显示：

1. matched-filter output
2. OS threshold
3. ACF sidelobe floor
4. hybrid threshold
5. OS extracted paths
6. hybrid extracted paths
7. true loaded CIR convolved with hybrid q:
   `h_effective = conv(h_true,q)`

同时自动计算：

- RMS delay spread before
- RMS delay spread after
- peak-to-sidelobe ratio before/after

输出：

`trm_ablation_metrics.csv/.mat`

不只看图。

---

# 32. c2 sensitivity 不再硬编码“Chosen c2=1/50”

当前脚本无论结果如何都画：

`Chosen c2 = 1/50`

这是不允许的。

重构：

- `quick`: 20 trials
- `pilot`: 100–200 trials
- `paper`: 300–500 trials（不要求 3000，因为这是 sensitivity）
- 至少 3 个动态 severity
- 使用真正 ground-truth tracking RMSE
- errorbar / CI

输出：

`c2_sensitivity.csv`

脚本只标记：

`cfg.c2`

但必须检查：

若 cfg.c2 的平均 RMSE 比最佳候选差 >5%：
输出 warning：

`Configured c2 is not supported by sensitivity study.`

不要自动篡改结果。

---

# 33. `export_paper_parameters` 禁止硬编码 c2

当前：

```matlab
\PaperCtwo{1/50}
```

必须改成由：

`cfg.c2`

自动输出。

参数文件同时输出：

- 31 chips
- 6 samples/chip
- actual num bits
- actual preamble duration
- actual HFM band
- N_vb
- c2
- reliability freeze threshold
- OS-CFAR config

---

# 34. `extract_paper_metrics.m` 扩展，但在 Paper Mode 完成前不得伪造

至少输出：

- per profile Proposed BER target SNR
- strongest-baseline target SNR
- SNR gain if both crossings exist
- sync failure rate at selected SNR
- frame error rate
- Stress in-fade RMSE
- Stress out-of-fade RMSE
- in-fade mean K gain
- in-fade mean R_eff/R_vb ratio
- runtime median

规则：

1. no extrapolation
2. no arbitrary `max(BER,1e-6)` in metric extraction
3. BER=0 measured point若用于 log interpolation：
   - 不得用任意 1e-6 伪值
   - 可保守报告 first measured SNR meeting target
   - 或报告 crossing interval
4. missing result -> `not available`
5. 不允许生成看似精确的假数字

---

# 35. Runtime benchmark 删除伪 FLOPs

当前：

```text
O(Nvb nx^3) = Nvb*8 FLOPs
O(nx) = 16 FLOPs
```

没有严格计数支撑。

本轮删除这些数字。

Benchmark 输出：

- MATLAB version
- platform
- CPU info if obtainable
- warmup
- repetitions
- mean
- median
- std
- ms/symbol

保存：

- `runtime_benchmark.csv`
- `paper_runtime_table.tex`

理论复杂度只写 operation structure，不写未验证 FLOP count。

---

# 36. Full pipeline 必须真执行，而不是“Full”但跳过核心步骤

把：

`src/run_paper2_full_pipeline.m`

改成函数：

```matlab
run_paper2_full_pipeline(mode)
```

mode：

- `quick`
- `pilot`
- `paper`

建议 counts：

```text
quick:
  BER 20
  stress 20
  sensitivity 20

pilot:
  BER 200
  stress 200
  sensitivity 100–200

paper:
  BER 3000
  stress 3000
  sensitivity 300–500
```

实际数值放 config。

pipeline 顺序：

1. load config
2. dependency check
3. run all unit tests
4. export parameters
5. BER validation
6. stress
7. TRM ablation
8. c2 sensitivity
9. benchmark
10. plots
11. extract metrics
12. alignment audit

**不允许注释 BER 或 Stress。**

任何 unexpected error：
pipeline fail。

---

# 37. 所有主要脚本尽量函数化

当前很多脚本：

`clear; clc; cd...`

容易破坏 pipeline state。

推荐函数化：

```matlab
main_WUWNET_Paper_Validation(mode)
main_WUWNET_Paper_Stress(mode)
generate_paper_trm_ablation(mode)
plot_sensitivity_c2(mode)
benchmark_paper2_receivers(mode)
```

每个函数：

- 自己 load config
- 返回 result struct/path
- 不依赖 caller workspace
- 不依赖 cwd

---

# 38. Random seed policy 必须可复现

当前：

`shuffle`

不适合最终论文复现。

config：

```matlab
cfg.master_seed = 20260823;
```

每 trial deterministic：

```matlab
rng(cfg.master_seed + unique_trial_index, 'twister');
```

A/B/C/D/E 必须共享：

- same data bits
- same Bellhop channel
- same noise
- same timing warp
- same fade

variant 内不得重新随机。

Pilot 和 Paper 可使用不同 base seed，但必须记录。

---

# 39. Fair comparison：不得让 E 拥有额外信息

所有 variants：

- same coarse sync output
- same raw received packet
- same preamble
- same payload start estimate
- same Early/Late spacing
- same initial state/P/Q where appropriate
- same decoded data

只有被消融的模块不同。

特别：

A/B/C/D/E 不允许独立重新同步后产生不同 random behavior。

建议在 wrapper 外先算 common sync metadata，然后传入 receiver。

---

# 40. 更新 `PAPER_CODE_ALIGNMENT.md`：不能提前 VERIFIED

当前 audit 把：

- MC Count=3000
- raw_results
- BER results

标成 VERIFIED，但 Paper run 尚未发生。

修正状态定义：

- `VERIFIED`: code + test/result file 已真实验证
- `PARTIAL`: implemented/configured，但 final experiment尚未完成
- `NOT IMPLEMENTED`: 明确不实现

在 Round-2 结束但 Paper Mode 未跑时：

- signal model可 VERIFIED（若 tests pass）
- Bellhop loader可 VERIFIED
- no-noise end-to-end可 VERIFIED
- MC=3000 应为 PARTIAL
- final BER claims应为 PARTIAL
- final performance gains应为 PARTIAL

不要为了 audit 好看全写 VERIFIED。

---

# 41. Round-2 的硬门槛

在回复我“Round-2 完成”之前，以下必须全部通过：

### Gate 1 — Signal model

- exact 31-chip
- chips = ±1
- samples/chip = 6
- symbol samples = 186
- HFM is true HFM
- payload and preamble same analytic-passband representation

### Gate 2 — Bellhop

3 个 real MAT loader tests pass。

### Gate 3 — Noiseless E2E

A/B/C/D/E：

```text
BER = 0
decoded length = exact num bits
```

### Gate 4 — Timing sign

known delay injection direction test pass。

### Gate 5 — Ground truth tracker

known smooth time warp下 E 的 estimated delay 与 true delay方向一致且 RMSE有限。

### Gate 6 — BER stats

all-fail synthetic case必须：

```text
BER = NaN
sync_fail_rate = 1
```

绝不能 BER=0。

### Gate 7 — D penalty

高可靠长序列下 R 不累积爆炸。

### Gate 8 — Q freeze

deep fade reliability触发 Q freeze test。

### Gate 9 — Quick full pipeline

```matlab
run_paper2_full_pipeline('quick')
```

必须真的依次执行：

BER + Stress + TRM + sensitivity + benchmark + plots + metrics

无注释跳过。

---

# 42. Gate 全通过后，只跑 Pilot，不跑 Paper

执行：

```matlab
run_paper2_full_pipeline('pilot')
```

建议 BER = 200 trials。

生成：

`results_plots/WUWNET_Paper/pilot/`

不得覆盖 paper results。

Pilot 结束后停止。

**不要自动开始 3000 MC。**

我们要先由 ChatGPT 审核 Pilot：

- BER curves
- confidence intervals
- failure rates
- tracking ground-truth RMSE
- Kalman gain
- R_eff/R_vb
- c2 sensitivity
- TRM focusing metrics

审核通过后再进入 Paper Mode。

---

# 43. 结果目录必须分层

建议：

```text
results_plots/WUWNET_Paper/
├── quick/
├── pilot/
└── paper/
```

每个目录保存：

- config snapshot
- seed
- timestamp
- git commit SHA if obtainable
- raw_results.mat
- CSV
- figures
- metric files

绝不能让 quick result 被误认为 paper result。

---

# 44. 文档更新

## `PAPER2_CHANGELOG.md`

新增 Round-2 section：

- fixed DSSS sampling
- fixed mseq selection
- true HFM
- consistent analytic passband
- explicit Bellhop loader
- fixed Variant A
- fixed D covariance pollution
- normalized reliability
- fixed Q freeze
- true timing-warp ground truth
- BER failure stats
- full pipeline
- new tests

## `BELLHOP_REPRODUCIBILITY.md`

明确：

- exact fields used
- complex or magnitude amplitude field
- normalization
- file names only encode Tx depth/range/Rx depth
- unverified bathymetric labels不得写成事实

---

# 45. 不要修改论文全文

Round-2 完成后：

不修改：

- Abstract
- Results text
- performance numbers
- conclusion gains

ChatGPT 会基于 Pilot 审核继续修改论文 V3。

---

# 46. Round-2 完成后的回复格式

只回复以下内容：

## A. Git

- latest commit SHA
- `git diff --stat` / changed-file list

## B. Gate results

逐条：

```text
Gate 1 Signal model: PASS/FAIL
Gate 2 Bellhop loader: PASS/FAIL
Gate 3 Noiseless E2E A-E: PASS/FAIL
Gate 4 Early-Late sign: PASS/FAIL
Gate 5 Ground-truth timing: PASS/FAIL
Gate 6 BER failure statistics: PASS/FAIL
Gate 7 Variant-D R stability: PASS/FAIL
Gate 8 Q-freeze: PASS/FAIL
Gate 9 Quick full pipeline: PASS/FAIL
```

## C. Exact noiseless E2E output

必须打印：

```text
A: decoded bits=?, errors=?, BER=?
B: ...
C: ...
D: ...
E: ...
```

## D. Bellhop loader output

每个 profile：

- number of paths
- amplitude field
- FIR length
- norm
- RMS delay spread

## E. Pilot summary

200-trial pilot：

每 channel / variant：

- BER_valid
- 95% CI
- sync fail rate
- frame error rate

## F. Stress summary

至少：

- C/D/E in-fade tracking RMSE
- out-of-fade RMSE
- E mean in-fade K gain
- E mean `R_eff/R_vb`
- valid trials

## G. c2 sensitivity

- best candidate by average RMSE
- cfg.c2 rank
- cfg.c2 vs best difference %
- 是否支持当前 `c2=1/50`

## H. Remaining PARTIAL / NOT IMPLEMENTED

从最新 `PAPER_CODE_ALIGNMENT.md` 原样列出。

## I. Do not run Paper Mode

结尾明确：

`Paper mode (3000 MC) NOT RUN; waiting for review.`

如果任一 Gate FAIL：
不要运行 Pilot；
先修复并重新测试。
