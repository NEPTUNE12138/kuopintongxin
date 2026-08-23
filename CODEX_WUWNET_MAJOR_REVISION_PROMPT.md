# WUWNET Paper 2 — Major Code/Experiment Revision Prompt for Codex

你现在工作在项目仓库 `NEPTUNE12138/kuopintongxin`（本地副本）。
目标不是“把曲线改好看”，而是让第二篇论文的 **method claim、代码实现、实验、图表、数值和可复现性完全一致**。

## 0. 最高优先级原则

1. **禁止修改 `最终项目文件/` 中与第一篇已发表论文对应的历史工程。**
   - 该目录视为 Paper 1 / baseline archive。
   - 除非为了修复阻塞运行的绝对路径等非算法错误，否则不要改算法、参数和历史结果。
2. 第二篇论文的权威实现位于根目录的：
   - `src/`
   - `lib/`
   - `Bellhop2YS/`（若本地存在）
   - `data/`
   - `results_plots/WUWNET*`
3. **禁止为了匹配论文文字而伪造代码，禁止为了匹配期望曲线而挑 seed。**
4. **禁止硬编码论文结论数字。**
   - 所有 BER 门限、SNR 增益、RMSE、运行时间等必须从 `.mat/.csv` 原始结果自动计算。
5. 单次“killer seed”结果不得作为主证据。
   - `find_killer_seed.m` 和 `plot_tracking_mechanism_single.m` 可保留为历史/调试脚本，但不得进入 Paper 2 的主结果流水线。
   - Paper 2 追踪机理图使用 ensemble Monte Carlo。
6. 最终修改完成后，**不要修改 `WUWNET_Paper_Overleaf_EN.md`**。
   - ChatGPT 将单独负责论文全文重写。
   - 你只负责生成准确的代码、结果、参数、图、指标和 alignment 文档。

---

# 1. 论文方法冻结：本轮只实现下面这条主线

Paper 2 的目标方法冻结为：

**DBPSK/DSSS**
→ **HFM preamble synchronization**
→ **Bellhop-derived multipath channel**
→ **Preamble-aware Hybrid Threshold CIR extraction**
→ **Time-Reversal pre-focusing**
→ **Early–Late noncoherent DLL**
→ **Heteroscedastic Variational-Bayesian Adaptive Kalman delay tracker (HVB-AKF)**
→ **differential noncoherent decoding**
→ **BER**

本轮明确 **删除/不实现** 以下 Paper 2 claim：

- 动态梯度更新 `c_{2,k}`
- 2D SNR–Delay Dynamic Routing
- “channel-aging error-floor elimination”
- DQPSK
- carrier-phase / Doppler PLL state `[theta, fd]`
- 未经硬件实测的 ARM latency

这些可以留作 future work，但不能进入主实验实现。

---

# 2. 统一第二篇论文的真实信号模型

当前 WUWNET 主代码实际是差分二进制 DSSS，不是 DQPSK。

必须统一为：

- binary data `a_k ∈ {±1}`
- differential symbol `d_k = a_k d_{k-1}`
- m-sequence spreading
- passband real carrier modulation
- noncoherent differential decoding

不要为了论文去改成 DQPSK。

当前核心参数以代码事实为准，预计包括但不限于：

- `fs = 48 kHz`
- `fc = 5 kHz`
- HFM preamble: `3–7 kHz`
- m-sequence length ≈ 31 chips（必须从实际数据读取，不允许手写假设）
- `N_pn = 6` in WUWNET paper simulations
- short frame ≈ 120 differential symbols
- SNR sweep ≈ `-14:1:0 dB`
- final Monte Carlo = 3000 trials unless runtime is prohibitive

所有参数必须进入统一 config，不允许散落在多个脚本里。

---

# 3. 新建统一 Paper 2 配置层

请新增：

`config/paper2_config.m`

它返回结构体 `cfg`，至少包含：

- sampling/carrier/preamble parameters
- m-sequence path / length
- symbol/frame settings
- SNR range
- Monte Carlo modes:
  - `quick`: 20–50 trials
  - `paper`: 3000 trials
- Early–Late spacing
- IAE window size
- VB forgetting factor
- VB inner iterations
- `c2`
- OS-CFAR:
  - Pfa
  - number of training cells
  - number of guard cells
  - order statistic index / fraction
- ACF sidelobe safety factor `kappa_side`
- random seed policy
- output paths
- Bellhop channel list and display names

所有 Paper 2 主程序从该 config 读取参数。

---

# 4. Hybrid Threshold TRM：必须真正实现，不得再用伪造 CIR 图

当前 `plot_trm_cfar_comparison.m` 使用“伪造 CIR”和固定 `p_sidelobe=0.25`。
这不能作为论文结果。

请新增：

## 4.1 `lib/os_cfar_1d.m`

要求：

- 对相关功率序列做真正的一维 Ordered-Statistic CFAR；
- 每个 CUT 使用左右训练单元；
- 排除 guard cells；
- 排序后取指定 order statistic；
- 如果使用目标 `Pfa`，请用有依据的指数噪声 OS-CFAR 关系数值求解 scaling factor；
- 若无法可靠完成 Pfa 标定，则接口和论文术语必须降级为
  `order-statistic adaptive threshold`
  而不是假称严格 CFAR；
- 输出：
  - threshold vector
  - detection mask
  - scaling factor / metadata

## 4.2 `lib/extract_cir_hybrid.m`

输入至少包括：

- matched-filter/correlation output
- known HFM preamble
- cfg

实现：

1. 在候选 CIR 窗内计算 OS-CFAR / order-statistic threshold；
2. 对**实际 HFM preamble**计算归一化自相关：
   `R_p = xcorr(preamble, preamble)`
3. 自动确定/配置 mainlobe exclusion region；
4. 求主瓣外最大旁瓣比：
   `rho_side = max(|R_p(side)|)/max(|R_p|)`
5. 以当前相关主峰尺度得到：
   `gamma_acf = kappa_side * rho_side * |g_peak|`
6. 最终：
   `gamma_hybrid[n] = max(gamma_os[n], gamma_acf)`
7. 提取：
   `h_ext[n] = g[n]` if `|g[n]| >= gamma_hybrid[n]`, else 0
8. 返回：
   - `h_ext`
   - `gamma_os`
   - `gamma_acf`
   - `gamma_hybrid`
   - detection masks
   - diagnostic metadata

TRM 使用复共轭时间反转：
`q[n] = conj(fliplr(h_ext))`

不要继续把 HFM 写成 LFM。

---

# 5. HVB-AKF：把当前“VB-like recursion”升级为数学上可解释的 VB 更新

不要再使用论文里不存在于代码的动态 `c_{2,k}`。

`c2` 固定，由敏感度实验选择，默认候选值保留 `1/50`，但最终必须由实验支持。

建议不要破坏旧函数，新增：

`lib/hvb_akf_delay_tracker.m`

## 5.1 状态必须是 DLL 码时延状态

定义：

`x_k = [epsilon_k; epsilon_dot_k]`

不是 carrier phase PLL。

- `epsilon`: sampling/code-delay offset
- `epsilon_dot`: delay drift rate

继续使用 Early/Prompt/Late correlation。

鉴别器：
`D_k = (L_power - E_power)/(L_power + E_power + eps)`

measurement:
`z_k = delta * D_k`

---

## 5.2 可靠性指标

Prompt despreading soft symbol：

`u_k = sum(seg_P .* mseq_ref)/(len_SS*N_pn)`

Differential reliability：

`m_k = abs(u_k * conj(u_{k-1}))`

采用固定超参数：

`Lambda_k = (1+c2)/(m_k^2 + c2)`

必要时做数值 clipping，但必须在输出 metadata 中记录 clipping 范围。
不要实现论文未验证的 gradient c2。

---

## 5.3 真正的 VB coordinate-ascent update

采用 inverse-Gamma measurement-noise prior。

保存跨时刻递推的 prior hyperparameters：

- `alpha_R`
- `beta_R`
- forgetting factor `rho_R`

每个符号：

1. 先做状态预测 `x_pred, P_pred`
2. 得到 prior hyperparameters：
   - `alpha0 = rho_R * alpha_prev`
   - `beta0  = rho_R * beta_prev`
3. 做固定 `N_vb` 次 inner VB iteration（建议 3，放 cfg）
4. 每次 iteration：
   - 用当前 posterior state 计算 expected residual energy：
     `Eres = (z - H*x_post)^2 + H*P_post*H'`
   - 更新：
     `alpha = alpha0 + 0.5`
     `beta  = beta0 + 0.5*Eres`
   - 使用 precision-matched effective covariance：
     `R_vb = beta / max(alpha, eps)`
   - heteroscedastic penalty **只用于 Kalman gain 的 effective covariance**：
     `R_eff = R_vb * Lambda_k`
   - 从同一 predicted prior `(x_pred,P_pred)` 重新做 measurement update
5. inner loop 完成后保存：
   - unpenalized `alpha,beta`
   - `R_vb`
   - `R_eff`
   - `K_gain`
6. penalty 不得写回 `alpha/beta` 的 sufficient statistics。
   这样才与“VB估计长期噪声，heteroscedastic penalty处理瞬时fade”的论文逻辑一致。

Q adaptation：

- 继承 Paper 1 的结构正则化思路；
- 若可靠度极低（例如 `Lambda_k > Lambda_freeze`），冻结 Q 更新；
- 可靠时可用 innovation-based diagonal update；
- 禁止产生非对角 Q；
- 输出 Q trace / diagonal history 以便调试。

---

# 6. 重新定义并统一所有 ablation baseline

不要再把 `df_iakf_pll(..., use_confidence=0)` 称为 Standard KF。

建议 Paper 2 最终使用 5 条曲线：

### A — No TRM + IAE-AKF
- 不做 TRM
- 使用 Paper 1 风格 structural IAE delay tracker
- 无 reliability penalty

### B — Conventional TRM + IAE-AKF
- 使用 pure OS-CFAR / order-statistic CIR extraction
- TRM
- IAE-AKF
- 无 reliability penalty

### C — Hybrid TRM + IAE-AKF
- 使用 Hybrid Threshold CIR extraction
- TRM
- IAE-AKF
- 无 reliability penalty

### D — Hybrid TRM + Confidence-Gated IAE-AKF
- Hybrid TRM
- 当前 heuristic confidence penalty：
  `1 + 50*exp(-2.5*m_k)` 或其统一配置版本
- 保留 IAE
- 作为“经验可靠性”baseline

### E — Hybrid TRM + HVB-AKF (Proposed)
- Hybrid TRM
- fixed-c2 heteroscedastic penalty
- VB covariance inference
- proposed method

这 5 条曲线能分别回答：

A→B：普通 TRM 的贡献  
B→C：Hybrid threshold 的贡献  
C→D：即时 reliability gating 的贡献  
D→E：VB covariance inference 相比 heuristic gating 的贡献

所有 BER、tracking、constellation、runtime 脚本必须调用同一套 variant wrapper。

建议新增：

`lib/run_paper2_receiver_variant.m`

禁止不同脚本中把同名 Baseline C 写成不同开关。

---

# 7. 新建权威 Paper 2 主实验，不直接继续堆旧脚本

新增：

`src/main_WUWNET_Paper_Validation.m`

它是 Paper 2 唯一权威 BER 主实验。

要求：

- 读取 `cfg`
- 遍历 3 个 Bellhop-derived channel profiles
- 遍历 SNR
- 遍历 MC trials
- 对 A/B/C/D/E 使用**同一份噪声 realization**
- 对所有 variant 使用同一 packet / same channel realization
- 记录：
  - total bit errors
  - total decoded bits
  - failed synchronization/tracking count
  - BER
  - valid trials
  - runtime
- BER 应优先按：
  `total_errors / total_decoded_bits`
  计算，而不是简单平均每 trial BER
- 保存 95% binomial/Wilson CI
- 所有 raw results 保存 `.mat`
- 同时导出 CSV

输出建议：

`results_plots/WUWNET_Paper/<channel>/raw_results.mat`
`results_plots/WUWNET_Paper/<channel>/ber_results.csv`

---

# 8. Extreme fading stress test：单独做，不能与普通 Bellhop BER 混淆

新增：

`src/main_WUWNET_Paper_Stress.m`

明确这是 controlled stress test，不是假称 Bellhop 自身产生了这些动态。

在 Bellhop-derived FIR 基础上叠加：

- controlled sinusoidal residual Doppler/phase drift
- fixed or randomized deep-fade intervals
- fade depth and duration from cfg

主机理证据：

- ensemble averaging
- 至少 1000 trials，paper mode 推荐 3000
- compare C/D/E 或至少 D/E
- 输出：
  - mean abs tracking error
  - RMSE
  - Kalman gain
  - `R_vb`
  - `R_eff`
  - reliability `m_k`
  - Lambda
- 带 95% confidence band / standard error band

严禁 `find_killer_seed` 参与主结果生成。

---

# 9. 重做 TRM 图：必须来自真实 pipeline

新增：

`src/generate_paper_trm_ablation.m`

必须从实际：

Bellhop channel
→ transmitted HFM preamble
→ channel filtering
→ controlled noise
→ matched filtering

得到实际 correlation output。

输出至少：

1. raw matched-filter/CIR candidate
2. pure OS-CFAR threshold + extracted paths
3. ACF sidelobe floor
4. hybrid threshold + extracted paths
5. equivalent CIR after time reversal

不得使用伪造 sinc CIR。

---

# 10. c2 敏感度分析重做

更新/重写：

`src/plot_sensitivity_c2.m`

要求：

- 使用实际 Paper 2 HVB tracker
- 使用至少 3 个 channel/dynamic regimes 或一个代表 channel + 多个 Doppler/fade severity
- 多 Monte Carlo，不能只 20 次作为最终结果
- 横轴 c2
- 指标：
  - tracking RMSE
  - optional BER
- 输出均值 + uncertainty
- 自动选择或证明 `c2 = 1/50` 是稳定折中
- 如果 `1/50` 并非最佳，不得强行保留，更新 cfg 和论文参数

---

# 11. 参数、指标、图表必须自动导出给论文

新增：

## `src/export_paper_parameters.m`

生成：

- `generated/paper_parameters.tex`
- `generated/paper_parameters.csv`

LaTeX 宏至少包含：

- `\PaperFs`
- `\PaperFc`
- `\PaperPreambleBand`
- `\PaperCodeLength`
- `\PaperSamplesPerChip`
- `\PaperFrameSymbols`
- `\PaperSNRRange`
- `\PaperMonteCarlo`
- `\PaperVBIterations`
- `\PaperCtwo`
- CFAR settings

## `src/extract_paper_metrics.m`

读取 final raw results，自动生成：

- `generated/paper_metrics.tex`
- `generated/paper_metrics.csv`

至少计算：

- each channel: BER=1e-3 crossing SNR (interpolated only when meaningful)
- Proposed vs strongest baseline SNR gain
- BER at selected SNRs
- tracking RMSE before/during/after fade
- average Kalman gain during fade
- synchronization failure rate
- confidence intervals

若某条曲线从未穿过 1e-3：
- 不得外推假值
- 输出 `not reached` / LaTeX 友好宏

---

# 12. 复杂度和 runtime：只报告真实测量

新增：

`src/benchmark_paper2_receivers.m`

要求：

- MATLAB version
- OS
- CPU model if MATLAB can query; otherwise允许人工写入 metadata
- warm-up
- repeated timing
- report median / mean / std per processed symbol
- A/B/C/D/E 分别测试

**不要生成 ARM 数据，除非本机真的连接并运行了 ARM。**
没有 ARM 测试就完全不输出 ARM 列。

理论复杂度必须根据实际实现写：
- 状态维度固定 2
- VB inner iterations = actual `N_vb`
- 不允许机械写 `O(n_x^3)` 而忽视标量 measurement / fixed 2-state implementation

---

# 13. Bellhop 可复现性检查

程序启动时检查：

`Bellhop2YS/`

以及 3 个目标 channel files。

如果文件缺失：

- 立即停止 final paper mode
- 明确列出缺失文件
- 不得创建假 Bellhop 数据顶替

若本地存在但 Git 未跟踪：
生成：

`BELLHOP_REPRODUCIBILITY.md`

记录：
- channel file names
- fields used (`delay_clean`, `amp_norm`, etc.)
- normalization
- generation source/config path
- sha256 of each channel MAT if possible

如果有 `.env/.bty/.ssp/.arr` 等原始 Bellhop 配置，整理到：
`Bellhop2YS/environments/`

---

# 14. 删除/隔离误导性绘图行为

更新：

`src/plot_all_3_channels_ber.m`

必须删除所有没有真实实验支持的：

- `Bypass Activated`
- `Error Floor Eliminated`
- -9 dB routing line

不允许绘图脚本“注释出一个算法模块”。

所有 figure caption/legend strings 从统一 variant metadata 生成。

---

# 15. Paper 2 命名统一

全项目第二阶段统一：

- “delay tracker” / “DLL”
- 不再叫 PLL，除非某个函数真的跟踪 carrier phase
- `phase_off` 变量改为 `delay_offset_samples`
- `tracking_error_history` 明确为 Early–Late delay discriminator / innovation quantity
- DBPSK/DSSS
- HFM preamble
- Bellhop-derived CIR
- Hybrid Threshold TRM
- HVB-AKF

旧函数可以保留兼容，但新 Paper 2 pipeline 不要使用错误命名。

---

# 16. 测试要求

新增 `tests/`：

### `test_signal_model.m`
验证发射链为 DBPSK/DSSS，不是 DQPSK。

### `test_hybrid_cir_extraction.m`
验证：
- hybrid threshold >= OS threshold
- ACF floor来自真实 HFM自相关
- 无NaN/Inf
- injected known paths可被合理检测

### `test_hvb_tracker.m`
验证：
- 高可靠条件下 Lambda 接近 1
- 深衰落下 Lambda 增大
- 深衰落下 `R_eff > R_vb`
- `K_gain` 相应下降
- `Q` 保持对角
- no NaN / divergence

### `test_variant_consistency.m`
确保 A/B/C/D/E 在所有脚本中的定义唯一。

先跑 unit tests，再跑 quick simulation。

---

# 17. Final paper-mode 执行顺序

请创建：

`src/run_paper2_full_pipeline.m`

顺序：

1. load config
2. dependency checks
3. unit tests
4. export parameters
5. final 3-channel BER simulation
6. extreme-fading ensemble
7. TRM real-data ablation
8. c2 sensitivity
9. runtime benchmark
10. generate figures
11. extract metrics
12. generate alignment report

中途任何阶段失败：
- 不得继续伪造后续文件
- 记录失败原因

---

# 18. 最终生成两个审计文档

## `PAPER_CODE_ALIGNMENT.md`

表格列：

| Paper claim | Code implementation | Experiment | Result file | Status |
|---|---|---|---|---|

必须覆盖：

- modulation
- state model
- Early–Late measurement
- Hybrid TRM
- OS-CFAR
- HFM ACF floor
- reliability metric
- VB update
- fixed c2
- structural Q
- A/B/C/D/E
- Bellhop profiles
- MC count
- BER metrics
- tracking mechanism
- runtime

Status 只能：
- VERIFIED
- PARTIAL
- NOT IMPLEMENTED

不得写模糊词。

## `PAPER2_CHANGELOG.md`

记录：
- modified/new files
- removed claims
- parameter changes
- experiment changes
- results regenerated
- known limitations

---

# 19. 禁止事项

- 不要修改第一篇论文的历史结果来“统一”第二篇。
- 不要伪造 Bellhop 文件。
- 不要把 HFM 写成 LFM。
- 不要把 DBPSK 写成 DQPSK。
- 不要把 delay DLL 写成 carrier PLL。
- 不要在没有 inner iteration 时声称 `N_iter` VB。
- 不要用 killer seed 做主证据。
- 不要手工在图上添加不存在的 routing/bypass。
- 不要硬编码 “4.5 dB gain”“-10 dB at 1e-3”等。
- 不要擅自修改论文英文全文。

---

# 20. 完成后的回复格式

完成后只给我：

1. `git diff --stat`
2. 新增/修改文件清单
3. unit test 结果
4. quick mode 结果摘要
5. paper mode 是否完整跑完
6. final result directories
7. `PAPER_CODE_ALIGNMENT.md` 中仍然 PARTIAL / NOT IMPLEMENTED 的项目
8. 任何无法完成的事项和原因

不要只回复“已完成”。
