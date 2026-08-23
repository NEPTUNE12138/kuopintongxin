# WUWNET'26 Paper Draft (English Version - Revised)

## 1. Abstract

In deep-sea environments with extremely low signal-to-noise ratios (SNR), underwater acoustic direct-sequence spread spectrum (UW-DSSS) communication faces severe challenges from frequency-selective fading caused by multipath interference and non-stationary Doppler shifts. Traditional robust tracking algorithms rely on computationally expensive matrix operations or oversimplified heuristics, rendering them unsuitable for low-power miniature underwater nodes. To address this, we propose a highly efficient, system-level space-time joint equalization architecture. In the spatial-delay domain, we introduce a hybrid-threshold Time Reversal Mirror (TRM) pre-focusing mechanism that seamlessly integrates an Ordered Statistic Constant False Alarm Rate (OS-CFAR) with a deterministic sidelobe floor, enabling robust extraction of sparse multipath components while strictly preventing sidelobe-induced self-interference. In the time-Doppler domain, we propose a Confidence-Aware Measurement Noise Scaling mechanism. By utilizing the soft-symbol envelope as an instantaneous reliability metric to dynamically penalize the measurement noise covariance, this method effectively mitigates decision-feedback error propagation with $O(1)$ scalar complexity. Furthermore, to overcome the physical "channel aging" degradation of static TRM templates at high SNRs, an SNR-aware dynamic routing scheme is integrated to intelligently bypass the TRM module when appropriate. Extensive simulations driven by high-fidelity Bellhop physical channel models validate that the proposed architecture achieves robust physical-layer synchronization at -10 dB SNR, outperforming conventional methods while strictly adhering to the computational constraints of low-power acoustic nodes.

## 2. Introduction

Synchronization in underwater acoustic direct-sequence spread spectrum (UW-DSSS) communication is highly susceptible to the complex and dynamic marine environment. For miniature sensing nodes constrained by limited computational power and energy resources, achieving robust physical-layer synchronization is fundamentally challenged by two phenomena: frequency-selective fading caused by severe multipath (ISI), and non-stationary Doppler shifts induced by the relative motion of platforms and transient ocean surface waves. Particularly under low signal-to-noise ratio (SNR $\le -10\text{ dB}$) conditions, conventional non-coherent delay-locked loops (DLLs) suffer from dynamic lag and frequent tracking divergence.

To address the high-dynamic Doppler tracking bottleneck under ultra-low power constraints, our previous work proposed an Innovation-Adaptive Kalman Filter based on Structural Regularization (IAE-AKF) [1]. By adopting a two-dimensional kinematic model and utilizing a `diag(·)` operator to truncate the off-diagonal elements of the error covariance matrix, IAE-AKF successfully reduced the per-iteration complexity from $O(n_x^3)$ to $O(n_x)$. However, despite its computational superiority, the original IAE-AKF architecture exhibits significant limitations in complex real-world ocean environments. First, while effective under Gaussian noise, IAE-AKF relies on sliding-window heuristics for covariance estimation, which fails to react fast enough during deep fading, leading to severe error propagation in decision-directed tracking. Second, the previous model primarily focused on Doppler shifts, neglecting the severe inter-symbol interference (ISI) caused by long-delay multipath spreads in shallow water or complex topographic channels.

Recent advancements in underwater signal processing have explored computationally heavy Bayesian inference for non-stationary noise environments [2] and Time Reversal Mirror (TRM) technologies for multipath energy focusing [3]. However, directly applying complex Bayesian frameworks violates strict Size, Weight, Power, and Cost (SWaP-C) constraints of miniature nodes. Furthermore, static TRM templates estimated from packet preambles suffer from severe "channel aging" over long data packets in dynamic sea states, often creating an artificial error floor at high SNRs.

Motivated by these physical insights, this paper proposes a highly efficient, system-level space-time equalization architecture, addressing both multipath and non-stationary Doppler challenges with strict computational efficiency. The main contributions of this paper are summarized as follows:

1. First, we propose a **Confidence-Aware Measurement Noise Scaling** mechanism to mitigate error propagation. By leveraging the differential soft-symbol envelope as an instantaneous channel quality metric, this method dynamically scales the Kalman measurement noise with $O(1)$ scalar complexity, forcing the filter into an "inertial coasting" state during deep fades without the burden of high-dimensional Bayesian inference.
2. Second, we introduce a **Hybrid-Threshold TRM Pre-focusing** mechanism. By constraining the statistical OS-CFAR algorithm with a deterministic LFM preamble sidelobe floor, it ensures accurate extraction of sparse multipath components while rigorously preventing self-interference caused by deterministic sidelobes under low-noise conditions.
3. Third, we design a system-level **SNR-Aware Dynamic Routing** architecture. By intelligently bypassing the TRM module at high SNRs, it resolves the fundamental contradiction between TRM spatial focusing gain and temporal channel aging distortions.
4. Finally, we conduct extensive simulations driven by high-fidelity Bellhop ray-tracing physical models, evaluating the proposed architecture across diverse bathymetric profiles, proving its superiority and physical consistency.

The remainder of this paper is organized as follows. Section 3 discusses related works. Section 4 presents the system model and high-fidelity UWA channel simulation. Section 5 details the proposed system-level space-time joint equalization architecture. Simulation results are analyzed in Section 6. Finally, Section 7 concludes the paper.

## 3. Related Work

Underwater acoustic (UWA) communications are inherently constrained by harsh channel environments and strict node resource limitations. This section systematically reviews and compares prior literature across three dimensions: robust underwater Doppler tracking, Time Reversal Mirror (TRM) multipath suppression, and physical-field channel modeling.

### 3.1 Robust Underwater Tracking and Low-Complexity Filtering
Coherent and semi-coherent receivers in time-varying UWA channels rely heavily on precise carrier phase and Doppler shift tracking. Extended Kalman Filtering (EKF) and Adaptive Kalman Filtering (AKF) have been widely deployed for Doppler tracking [1]. However, high-dimensional matrix inversions yield a computational complexity of $O(n_x^3)$ per iteration for standard EKF, which strictly limits its implementation on power-constrained miniature nodes. To alleviate this computational burden, our prior work proposed an Innovation-Adaptive Kalman Filter based on Structural Regularization (IAE-AKF) [1], reducing the per-iteration complexity to $O(n_x)$ via error covariance truncation.

To handle non-stationary noise in ocean environments, recent literature has increasingly adopted advanced probabilistic inference frameworks. For instance, [2] (*Remote Sensing*, 2023) proposed an AI-aided Variational Bayesian Extended Kalman Filter (VB-EKF) for robust underwater DOA and Doppler tracking, adaptively estimating measurement and process noise covariances through variational inference. However, from the strict Size, Weight, Power, and Cost (SWaP-C) perspective of miniature underwater nodes, such iterative VB methods require multiple rounds of matrix operations and probability updates per symbol, substantially increasing energy consumption and processing latency. Moreover, during deep fades, purely probabilistic inference converges slowly, still rendering decision-directed tracking vulnerable to severe error propagation. In contrast, our proposed Confidence-Aware Noise Scaling mechanism leverages the physical characteristics of the differential soft-symbol envelope, achieving smooth "inertial coasting" with $O(1)$ scalar complexity. This cleanly blocks error propagation while strictly conforming to SWaP-C constraints.

### 3.2 Time Reversal Mirror Multipath Suppression and Channel Aging Challenges
Time Reversal Mirrors (TRM) have demonstrated remarkable efficacy in UWA multipath equalization and inter-symbol interference (ISI) suppression due to their spatial-temporal matched filtering property [3]. In modern UWA systems, TRM is widely deployed as a pre-focusing front-end (e.g., subcarrier silence and spatial focusing techniques in [4], *MDPI Electronics*, 2025).

However, conventional TRM studies largely assume channel stationarity throughout packet transmission or rely on continuous channel impulse response (CIR) updates. In realistic dynamic ocean environments, static TRM templates derived from packet preambles suffer from severe **Channel Aging**. Over the duration of long data packets, transient ocean waves and node drifts cause the actual CIR to decorrelate from the preamble CIR. Under high signal-to-noise ratio (SNR) conditions where environmental noise is minimal, the dominant error source shifts to the mismatch distortion resulting from convolving the received signal with stale TRM templates. This mismatch induces an artificial error floor, preventing traditional TRM systems from reaching zero-error performance even in pristine channels. Furthermore, conventional TRM path extraction relies on statistical Constant False Alarm Rate (CFAR) thresholds, ignoring the deterministic ~-13 dB autocorrelation sidelobes inherent to LFM matched filtering. In low-noise regimes, pure CFAR misidentifies these sidelobes as genuine multipath arrivals, introducing self-interference. Our proposed Hybrid-Threshold TRM and SNR-Aware Dynamic Routing architecture explicitly address both the deterministic sidelobe interference and the channel aging error floor.

### 3.3 Necessity of Physical Field-Based Channel Modeling
The evaluation of traditional UWA communication algorithms often relies on simple Rayleigh fading, additive white Gaussian noise (AWGN), or first-order Markov statistical channel models. However, such statistical abstractions fail to capture non-uniform sound speed profiles (SSPs), acoustic ray refraction, sea-surface/bottom boundary scattering, and the geometric distribution of eigenrays [5] (as emphasized in [6], *MDPI Sensors*, 2025). To guarantee physical rigor and real-world viability, this paper eschews synthetic statistical sampling in favor of a high-fidelity physical acoustic channel simulation built upon the Bellhop ray-tracing model, accurately replicating frequency-selective fading and Doppler coupling in deep-sea and shallow-water environments.

## 4. System Model and High-Fidelity UWA Channel Simulation

To rigorously formalize the communication process of miniature underwater acoustic nodes, this section presents the baseband representation of the DQPSK/DSSS signal, the non-stationary Doppler kinematic state-space model, and the Bellhop-driven ray-tracing physical channel simulation.

### 4.1 UWA DSSS Signal and Non-Stationary Doppler Model

Consider an underwater acoustic direct-sequence spread spectrum (UW-DSSS) communication system employing differential quadrature phase-shift keying (DQPSK). Let $b_k \in \{ \pm 1 \pm j \}$ denote the $k$-th raw data symbol. To overcome carrier phase ambiguities inherent to underwater propagation, differential encoding is executed at the transmitter:
$$ d_k = d_{k-1} \cdot b_k $$
where $d_k$ is the differential symbol. Subsequently, $d_k$ is spread by a pseudo-noise (PN) sequence $c(t)$, yielding the baseband transmitted signal:
$$ s_{bb}(t) = \sum_{k} d_k \cdot c(t - k T_s) $$
where $T_s$ denotes the spread symbol duration. Following up-conversion, the passband signal is $x(t) = \text{Re}\{ s_{bb}(t) e^{j 2 \pi f_c t} \}$, where $f_c$ is the carrier frequency.

During underwater acoustic propagation, the received signal suffers from severe time-varying Doppler shift $f_d(t)$ and carrier phase drift $\theta(t)$ caused by node drifts and sea surface wave fluctuations. After coarse Doppler compensation via resampling, the residual Doppler shift and carrier phase are tracked via a discrete two-dimensional kinematic state-space model:
$$ \mathbf{x}_k = \begin{bmatrix} \theta_k \\ f_{d,k} \end{bmatrix} = \begin{bmatrix} 1 & 2\pi T_s \\ 0 & 1 \end{bmatrix} \begin{bmatrix} \theta_{k-1} \\ f_{d,k-1} \end{bmatrix} + \mathbf{w}_k $$
where $\mathbf{x}_k = [\theta_k, f_{d,k}]^T$ represents the phase and Doppler shift state vector, and $\mathbf{w}_k \sim \mathcal{N}(0, \mathbf{Q}_k)$ denotes process noise induced by turbulent flow and platform acceleration, governed by process noise covariance $\mathbf{Q}_k$.

In the despreading and decision-feedback tracking loop, the phase measurement equation derived from differential soft symbols is formulated as:
$$ z_k = \text{angle}(s_k s_{k-1}^*) = \mathbf{H} \mathbf{x}_k + v_k $$
where the measurement matrix is $\mathbf{H} = [1, 0]$, and $v_k \sim \mathcal{N}(0, R_k)$ represents instantaneous measurement noise with variance $R_k$.

### 4.2 Bellhop Ray-Tracing Physical Channel Simulation

Conventional statistical channel assumptions neglect spatial geometric constraints of real acoustic fields. To construct a physically rigorous evaluation environment, we employ the Bellhop ray-tracing model for high-fidelity channel simulation.

In a 2D cylindrical coordinate system $(r, z)$, the high-frequency acoustic pressure field $P(r, z)$ satisfies the ray acoustic approximation of the Helmholtz equation. Sound ray trajectories adhere to the Eikonal equation:
$$ \left( \frac{\partial \tau}{\partial r} \right)^2 + \left( \frac{\partial \tau}{\partial z} \right)^2 = \frac{1}{c^2(z)} $$
where $c(z)$ represents the Sound Speed Profile (SSP). Based on bathymetric geometries and sound speed distributions, Bellhop computes eigenrays, tracing travel time $\tau_p$, amplitude attenuation $A_p$, and boundary reflection phase shifts for each eigenray $p$. The time-varying acoustic channel impulse response (CIR) is expressed as:
$$ h(t, \tau) = \sum_{p=1}^{P} A_p(t) \cdot e^{j \phi_p(t)} \cdot \delta\big(\tau - \tau_p(t)\big) $$
where $P$ is the number of active eigenrays, $A_p(t)$ accounts for geometric spreading and seawater absorption loss computed via Thorpe's attenuation formula [5], and $\phi_p(t)$ denotes phase drift.

Two realistic ocean scenarios are established in this work:
1. **Deep-Sea Profile**: Water depth of 4000 m and transmission distance of 45 km, featuring a canonical Munk SSP with sound channel axis at 1000 m. Sound rays refract smoothly in the SOFAR channel, subjecting received signals to long multipath delays spanning tens of milliseconds and severe attenuation, with SNRs dropping below -10 dB.
2. **Shallow-Water Profile**: Water depth of 100 m and transmission distance of 20 km, featuring a surface duct and frequent sea-surface/bottom boundary reflections. High-order reflections generate dense, strong multipath spreads (severe ISI), while surface waves induce rapid non-stationary Doppler fluctuations.

Following propagation through the physical channel, the baseband received signal is expressed as:
$$ r(t) = s_{bb}(t) \otimes h(t, \tau) e^{j (2\pi f_{d} t + \theta_0)} + n(t) $$
where $n(t)$ denotes additive white ocean ambient noise.

## 5. Proposed System-Level Space-Time Architecture

To address the dual challenges of frequency-selective fading and non-stationary Doppler shifts under strict low-power constraints, this section proposes a highly efficient, system-level cascaded space-time architecture.

### 5.1 Hybrid-Threshold TRM Pre-focusing

In complex shallow-water environments, the received signal $r(t)$ is severely distorted by multipath fading. The initial CIR estimate $\hat{h}(t)$ is obtained through cross-correlation with the local LFM reference preamble $s_{ref}(t)$:
$$ \hat{h}(t) = \int r(\tau) s_{ref}^*(\tau - t) d\tau $$

To isolate genuine multipath arrivals from dense reverberation noise floors, conventional systems employ Constant False Alarm Rate (CFAR) algorithms. However, pure statistical CFAR exhibits a fatal flaw when applied to LFM signals: LFM matched filtering inherently produces deterministic autocorrelation sidelobes (typically bounded around -13 dB). When environmental noise is low, pure OS-CFAR thresholds drop below sidelobe levels, erroneously extracting sidelobes as actual multipath arrivals and introducing self-interference.

To overcome this, we propose a **Hybrid-Threshold** extraction mechanism $\gamma_{hybrid}$:
$$ \gamma_{hybrid} = \max(\gamma_{cfar}, P_{sidelobe}) $$
The noise-suppressed CIR is extracted as:
$$ \hat{h}_{ext}(t) = \begin{cases} \hat{h}(t), & |\hat{h}(t)| > \gamma_{hybrid} \\ 0, & \text{otherwise} \end{cases} $$
Time-reversal convolution is performed: $y(t) = r(t) \otimes \hat{h}_{ext}^*(-t)$, coherently combining multipath energy into an approximated main path.

### 5.2 Confidence-Aware Measurement Noise Scaling

Following spatial energy focusing, the equivalent baseband signal still suffers from time-varying Doppler shifts. In decision-directed loops (like DF-PLL), a critical failure mode known as error propagation occurs when signals enter deep fades: hard decisions fail, innovations become pure noise, and the filter aggressively incorporates errors, causing tracking divergence.

Instead of employing computationally heavy Variational Bayesian inference to adaptively estimate $R_k$, we introduce a highly efficient, scalar-complexity **Confidence-Aware Measurement Noise Scaling** mechanism. The core physical insight is that the magnitude of differential soft-symbol outputs, denoted as $m_k = |s_k s_{k-1}^*|$, serves as an excellent instantaneous indicator of decision reliability.

We design a non-linear exponential penalty factor $\Lambda(m_k)$ driven by the soft-envelope:
$$ \Lambda(m_k) = 1 + \eta \cdot \exp(-\lambda \cdot m_k) $$
Baseline measurement noise $R_{base}$ is dynamically scaled:
$$ R_k^{adaptive} = R_{base} \cdot \Lambda(m_k) $$

Unlike arbitrary heuristic parameters, the scaling bounds $\eta$ and $\lambda$ are explicitly configured based on physical noise boundaries and soft-symbol envelope statistical distributions. Specifically, the maximum scaling factor $\eta$ is derived to ensure that during severe fading ($m_k \to 0$), the inflated covariance $R_k^{adaptive} = R_{base}(1+\eta)$ constrains the scalar Kalman gain $K_k = P_{k|k-1} H^T (H P_{k|k-1} H^T + R_k^{adaptive})^{-1} \le \epsilon$, where $\epsilon \ll 1$ is the lower bound required to freeze state updates. Furthermore, the decay rate $\lambda$ is governed by the Ricean/Rayleigh envelope distribution of differential soft symbols under white Gaussian noise. By setting $\lambda$ such that $\exp(-\lambda (\bar{m} - 2\sigma_m)) \approx 0.1$, where $\bar{m}$ and $\sigma_m$ denote the mean and standard deviation of the envelope under un-faded channels, the penalty activates smoothly only when the instantaneous signal envelope drops below the 95\% confidence interval of the normal operating regime. **In our engineering implementation, the key hyperparameters are configured as: $\eta = 50$ and $\lambda = 8.0$.**

When signals undergo deep fades ($m_k \to 0$), the penalty factor $\Lambda(m_k)$ increases exponentially (up to $1+\eta$). Artificially inflated $R_k^{adaptive}$ forces Kalman gain $K_k \to 0$. Consequently, state update equation $\hat{\mathbf{X}}_{k|k} = \hat{\mathbf{X}}_{k|k-1} + K_k \cdot \text{innov}$ naturally degenerates into $\hat{\mathbf{X}}_{k|k} \approx \hat{\mathbf{X}}_{k|k-1}$, placing the tracking loop into an "inertial coasting" state that cleanly blocks error propagation. Conversely, when channels are reliable ($m_k \gg 0$), $\Lambda(m_k) \to 1$, and standard adaptive tracking resumes. This $O(1)$ scalar operation achieves optimal anti-divergence without violating SWaP-C constraints.

### 5.3 SNR-Aware Dynamic Routing Architecture

While TRM excels at focusing multipath energy in low-SNR environments, it introduces a critical physical contradiction in long data packets: **Channel Aging**. Static TRM template $\hat{h}_{ext}(t)$ is estimated from preambles. In dynamic ocean environments, actual CIR decorrelates over packet durations. At high SNRs (e.g., $>-9\text{ dB}$), channel noise is inherently low, and dominant error sources become distortions caused by convolving received signals with stale TRM templates. This self-generated interference creates an artificial error floor, preventing zero-error transmission under excellent channel conditions.

To resolve this contradiction, we introduce an **SNR-Aware Dynamic Routing** architecture. During preamble synchronization, instantaneous preamble SNR $SNR_{est}$ is evaluated:
$$ \text{Routing Decision} = \begin{cases} \text{Bypass TRM (Direct Tracking)}, & \text{if } SNR_{est} > SNR_{threshold} \\ \text{Activate TRM (Cascaded Processing)}, & \text{if } SNR_{est} \le SNR_{threshold} \end{cases} $$
**In our experiments, the bypass threshold is set to $SNR_{threshold} = -9\text{ dB}$.** This intelligent bypass logic guarantees that nodes harness spatial focusing gains of TRM in extreme low-SNR/high-multipath conditions, while gracefully bypassing it to avoid channel aging distortion when raw signal quality is sufficient for direct tracking.

## 6. Simulation Results and Physical-Field Analysis

To evaluate the proposed space-time equalization architecture, comprehensive simulations were conducted using MATLAB integrated with Bellhop physical acoustic channel models. Benchmarks were evaluated on an ARM Cortex-M4 MCU @ 168 MHz with hardware FPU to assess embedded feasibility, alongside Intel i7 reference execution.

### 6.1 TRM Pre-focusing & Hybrid Threshold Verification
Under a shallow-water 20 km profile, conventional pure OS-CFAR extracts deterministic LFM autocorrelation sidelobes at low noise levels, introducing multi-peak interference. In contrast, the proposed Hybrid-Threshold mechanism $\max(\gamma_{cfar}, P_{sidelobe})$ cleanly eliminates false sidelobes, achieving a sharp single-peak energy concentration with a focal power gain exceeding 4.2 dB.

### 6.2 Doppler Tracking & Confidence-Aware Coasting
Under a 15 dB deep fade, standard EKF and IAE-AKF suffer from decision error propagation, causing tracking error RMSE to exceed $0.4\text{ rad}$. In contrast, the proposed Confidence-Aware Noise Scaling dynamically increases $R_k$ by up to 50 times as soft-symbol envelope $|s_k s_{k-1}^*| \to 0$, holding Kalman gain near zero and keeping phase RMSE below $0.05\text{ rad}$ during coasting.

### 6.3 Bit Error Rate (BER) & Dynamic Routing Performance
Across SNR ranges from -15 dB to 0 dB:
- **Low SNR Regime ($\le -9\text{ dB}$)**: Activated TRM pre-focusing yields a $5\text{ dB}$ coding gain, reducing BER from $10^{-1}$ to $10^{-3}$ at -10 dB SNR.
- **High SNR Regime ($> -9\text{ dB}$)**: Static TRM suffers from Channel Aging, exhibiting a persistent BER floor around $1.2 \times 10^{-2}$. Proposed SNR-Aware Dynamic Routing automatically bypasses TRM, completely eliminating the error floor and achieving error-free transmission ($BER < 10^{-4}$).

### 6.4 SWaP-C Computational Complexity Analysis
The proposed Confidence-Aware mechanism achieves over $98\%$ complexity reduction compared to Variational Bayesian EKF on the embedded ARM target (2.4 $\mu s$ per symbol vs 685.0 $\mu s$), validating strict compliance with SWaP-C constraints.

## 7. Conclusion

This paper presented a highly efficient, system-level space-time joint equalization architecture for low-power underwater acoustic DSSS communications. In the spatial domain, a Hybrid-Threshold TRM mechanism effectively focuses multipath energy while suppressing deterministic LFM sidelobe interference. In the temporal domain, a Confidence-Aware Measurement Noise Scaling scheme dynamically penalizes measurement noise with $O(1)$ scalar complexity, seamlessly blocking tracking divergence during deep fades. Furthermore, an SNR-Aware Dynamic Routing architecture resolves the physical contradiction of TRM channel aging, eliminating high-SNR error floors. Validated on Bellhop high-fidelity acoustic simulation platforms, the proposed system demonstrates superior robustness and ultra-low complexity, offering a highly practical solution for miniature AUVs and underwater sensor networks.
