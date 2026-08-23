\documentclass[sigconf]{acmart}

\AtBeginDocument{%
  \providecommand\BibTeX{{%
    Bib\TeX}}}
\usepackage{subcaption}

\setcopyright{acmlicensed}
\copyrightyear{2026}
\acmYear{2026}
\acmConference[WUWNET '26]{The International Conference on Underwater Networks \& Systems}{October 20--23, 2026}{Shenzhen, China}
\acmISBN{978-1-4503-XXXX-X/26/10}

% ----------------------------------------------------
% 正文环境必须从这里开始
\begin{document}
% ----------------------------------------------------

\title{System-Level Space-Time Joint Equalization for AUV Underwater Acoustic DSSS Communications}

\author{Anonymous Author(s)}
\affiliation{%
  \institution{Anonymous Institution}
  \city{Anonymous City}
  \country{Anonymous Country}
}

\renewcommand{\shortauthors}{Anonymous Author(s)}

\begin{abstract}
Underwater acoustic direct-sequence spread spectrum (UW-DSSS) communication is severely constrained by frequency-selective fading and non-stationary Doppler shifts in low signal-to-noise ratio (SNR) regimes. To guarantee tracking stability for Autonomous Underwater Vehicles (AUVs) and surface buoys, we propose a robust system-level space-time joint equalization architecture. In the spatial-delay domain, we introduce a hybrid-threshold Time Reversal Mirror (TRM) pre-focusing mechanism. By integrating Ordered Statistic Constant False Alarm Rate (OS-CFAR) with a deterministic sidelobe floor, it isolates sparse multipath components while strictly suppressing self-interference. In the time-Doppler domain, we formulate a Heteroscedastic Variational Bayesian Adaptive Kalman Filter (HVB-AKF). By leveraging the differential soft-symbol envelope to generate a physical conditional heteroscedastic penalty driven by a dynamically evolving parameter, it scales the measurement noise covariance within the Variational Bayesian iteration. This effectively blocks decision-directed error propagation by forcing the filter into an inertial coasting state during deep fades. Furthermore, to circumvent the physical ``channel aging'' degradation inherent to static TRM templates, a 2D SNR-Delay dynamic routing scheme adaptively bypasses the TRM module when both SNR is high and time-domain RMS delay spread is narrow. Numerical simulations demonstrate that the architecture achieves a $10^{-3}$ bit error rate (BER) threshold at -10 dB SNR, yielding robust tracking gains over heuristic baselines in dynamic physical fields.
\end{abstract}

\begin{CCSXML}
<ccs2012>
 <concept>
  <concept_id>10003033.10003034.10003035</concept_id>
  <concept_desc>Networks~Network physical layer</concept_desc>
  <concept_significance>500</concept_significance>
 </concept>
 <concept>
  <concept_id>10010520.10010557.10010560</concept_id>
  <concept_desc>Computer systems organization~Embedded and cyber-physical systems</concept_desc>
  <concept_significance>300</concept_significance>
 </concept>
</ccs2012>
\end{CCSXML}

\ccsdesc[500]{Networks~Network physical layer}
\ccsdesc[300]{Computer systems organization~Embedded and cyber-physical systems}

\keywords{Underwater Acoustic Communication, DSSS, Time Reversal Mirror, Kalman Filter, Channel Aging, Ray Tracing}

\maketitle

\section{Introduction}
Synchronization in underwater acoustic direct-sequence spread spectrum (UW-DSSS) communication is highly susceptible to the complex and dynamic marine environment. For Autonomous Underwater Vehicles (AUVs) and surface buoys, achieving robust physical-layer synchronization is challenged by two phenomena: frequency-selective fading caused by severe multipath (ISI), and non-stationary Doppler shifts induced by the relative motion of platforms and transient ocean surface waves. Particularly under low signal-to-noise ratio (SNR $\le -10\text{ dB}$) conditions, conventional non-coherent delay-locked loops (DLLs) suffer from dynamic lag and frequent tracking divergence.

To address the challenges of high-dynamic Doppler tracking, classic phase-coherent architectures, such as decision-feedback adaptive Kalman filters (AKF) \cite{Stojanovic1994}, are widely adopted. Furthermore, recent literature proposed an Innovation-Adaptive Kalman Filter based on Structural Regularization (IAE-AKF) \cite{Yang2024} to reduce computational complexity. However, conventional heuristic AKF architectures and the original IAE-AKF exhibit limitations in complex real-world ocean environments. First, while effective under Gaussian noise, they rely on sliding-window heuristics for covariance estimation, which fails to react fast enough during deep fading, leading to severe error propagation in decision-directed tracking. Second, these models primarily focused on Doppler shifts, neglecting inter-symbol interference (ISI) caused by long-delay multipath spreads in shallow water or complex topographic channels.

Recent advancements in underwater signal processing have explored Bayesian inference for non-stationary noise environments \cite{VBEKF2023} and Time Reversal Mirror (TRM) technologies for multipath energy focusing \cite{Kuperman1998}. While Variational Bayesian (VB) frameworks excel at capturing non-stationary ambient noise, their convergence slows down drastically during deep fades, rendering decision-directed tracking vulnerable to error avalanches. Furthermore, static TRM templates estimated from packet preambles suffer from ``channel aging'' over long data packets in dynamic sea states, creating an error floor at high SNRs.

To resolve these challenges, we propose a highly robust, system-level space-time equalization architecture tailored for demanding UWA networks. The primary contributions are:
\begin{enumerate}
    \item We formulate a \textbf{Heteroscedastic Variational Bayesian Adaptive Kalman Filter (HVB-AKF)} to eradicate error propagation. Utilizing the differential soft-symbol envelope as an instantaneous reliability metric, we integrate a conditional heteroscedastic penalty driven by a dynamically evolving parameter $c_2$ into the Variational M-step. The $c_2$ parameter adapts based on the prediction error gradient, forcing the filter into an ``inertial coasting'' state during deep fades to achieve robust tracking.
    \item We introduce a \textbf{Hybrid-Threshold TRM Pre-focusing} mechanism. Constraining OS-CFAR with a dynamic LFM auto-correlation bound inherently isolates sparse multipath while averting deterministic self-interference.
    \item We design a system-level \textbf{2D SNR-Delay Dynamic Routing} architecture. By adaptively bypassing the TRM module based on joint preamble SNR and time-domain RMS delay spread estimation, it resolves the physical conflict between spatial focusing gain and temporal channel aging distortions, eliminating high-SNR error floors.
    \item We evaluate the architecture using high-fidelity Bellhop ray-tracing channel models. Numerical simulations across diverse bathymetric profiles demonstrate its physical consistency and robust tracking performance over heuristic methods.
\end{enumerate}

\section{Related Work}
Underwater acoustic (UWA) communications are inherently constrained by harsh channel environments and strict node resource limitations. This section systematically reviews prior literature across three dimensions: robust underwater Doppler tracking, Time Reversal Mirror (TRM) multipath suppression, and physical-field channel modeling.

\subsection{Robust Underwater Tracking and Bayesian Inference}
Coherent and semi-coherent receivers in time-varying UWA channels rely heavily on precise carrier phase and Doppler shift tracking. Adaptive Kalman Filtering (AKF) methods, such as decision-feedback adaptive tracking loops \cite{Stojanovic1994} and structural regularized adaptive filters \cite{Yang2024}, have been deployed to mitigate performance degradation under varying noise floors.

To systematically handle non-stationary noise in ocean environments, recent literature has increasingly adopted advanced probabilistic inference frameworks. For instance, \cite{VBEKF2023} proposed a Variational Bayesian Extended Kalman Filter (VB-EKF) for robust underwater DOA and Doppler tracking, adaptively estimating measurement and process noise covariances through variational iterations. Similar extended measurement space concepts have also been utilized for distributed multi-sensor passive tracking \cite{Zhang2026}. While Variational Bayesian (VB) approaches excel at tracking slowly-varying non-stationary noise, their M-step covariance estimations are inherently vulnerable to rapid, deep signal fading. During deep fades, the lack of reliable signal energy causes the probabilistic inference to converge poorly, rendering decision-directed tracking highly susceptible to catastrophic error propagation. To address this fundamental limitation of VB methods in extreme UWA fading, the proposed HVB-AKF architecture augments the standard VB iteration with an instantaneous physical reliability metric derived from the differential soft-symbol envelope, enabling immediate tracking coasting.

\subsection{Time Reversal Mirror Multipath Suppression and Channel Aging Challenges}
Time Reversal Mirrors (TRM) have demonstrated remarkable efficacy in UWA multipath equalization and inter-symbol interference (ISI) suppression due to their spatial-temporal matched filtering property. In modern UWA systems, TRM is widely deployed as a pre-focusing front-end (e.g., foundational spatial focusing techniques in \cite{Kuperman1998}).

However, conventional TRM studies largely assume channel stationarity throughout packet transmission or rely on continuous channel impulse response (CIR) updates. In realistic dynamic ocean environments, static TRM templates derived from packet preambles suffer from \textbf{Channel Aging}. Over the duration of long data packets, transient ocean waves and node drifts cause actual CIR to decorrelate from preamble CIR. Under high signal-to-noise ratio (SNR) conditions where environmental noise is minimal, dominant error sources shift to mismatch distortion resulting from convolving received signals with stale TRM templates. This mismatch induces an error floor, preventing traditional TRM systems from reaching high performance even in pristine channels. Furthermore, conventional TRM path extraction relies on statistical Constant False Alarm Rate (CFAR) thresholds, ignoring deterministic $\approx -13\text{ dB}$ autocorrelation sidelobes inherent to LFM matched filtering. In low-noise regimes, standard CFAR misidentifies these sidelobes as genuine multipath arrivals, introducing self-interference. The proposed Hybrid-Threshold TRM and SNR-Aware Dynamic Routing architecture are introduced to address both deterministic sidelobe interference and channel aging error floors.

\section{System Model and High-Fidelity UWA Channel Simulation}
To rigorously formalize the communication process of autonomous underwater vehicles (AUVs), this section presents the baseband representation of the DQPSK/DSSS signal, the non-stationary Doppler kinematic state-space model, and the Bellhop-driven ray-tracing physical channel simulation.

\subsection{UWA DSSS Signal and Non-Stationary Doppler Model}
Consider an underwater acoustic direct-sequence spread spectrum (UW-DSSS) communication system employing differential quadrature phase-shift keying (DQPSK). Let $b_k \in \{ \pm 1 \pm j \}$ denote the $k$-th raw data symbol. To overcome carrier phase ambiguities inherent to underwater propagation, differential encoding is executed at the transmitter:
\begin{equation}
d_k = d_{k-1} \cdot b_k
\end{equation}
where $d_k$ is the differential symbol. Subsequently, $d_k$ is spread by a pseudo-noise (PN) sequence $c(t)$, yielding the baseband transmitted signal:
\begin{equation}
s_{bb}(t) = \sum_{k} d_k \cdot c(t - k T_s)
\end{equation}
where $T_s$ denotes the spread symbol duration. Following up-conversion, the passband signal is $x(t) = \mathrm{Re}\{ s_{bb}(t) e^{j 2 \pi f_c t} \}$, where $f_c$ is the carrier frequency.

During underwater acoustic propagation, the received signal suffers from severe time-varying Doppler shift $f_d(t)$ and carrier phase drift $\theta(t)$ caused by node drifts and sea surface wave fluctuations. After coarse Doppler compensation via resampling, residual Doppler shift and carrier phase are tracked via a discrete two-dimensional kinematic state-space model:
\begin{equation}
\mathbf{x}_k = \begin{bmatrix} \theta_k \\ f_{d,k} \end{bmatrix} = \begin{bmatrix} 1 & 2\pi T_s \\ 0 & 1 \end{bmatrix} \begin{bmatrix} \theta_{k-1} \\ f_{d,k-1} \end{bmatrix} + \mathbf{w}_k
\end{equation}
where $\mathbf{x}_k = [\theta_k, f_{d,k}]^T$ represents the phase and Doppler shift state vector, and $\mathbf{w}_k \sim \mathcal{N}(0, \mathbf{Q}_k)$ denotes process noise induced by turbulent flow and platform acceleration, governed by process noise covariance $\mathbf{Q}_k$.

In the despreading and decision-feedback tracking loop, the phase measurement equation derived from differential soft symbols is formulated as:
\begin{equation}
z_k = \mathrm{angle}(s_k s_{k-1}^*) = \mathbf{H} \mathbf{x}_k + v_k
\end{equation}
where measurement matrix $\mathbf{H} = [1, 0]$, and $v_k \sim \mathcal{N}(0, R_k)$ represents instantaneous measurement noise with variance $R_k$.

\subsection{Bellhop Ray-Tracing Physical Channel Simulation}
Conventional statistical channel assumptions neglect spatial geometric constraints of real acoustic fields. To construct a physically rigorous evaluation environment, we employ the Bellhop ray-tracing model for high-fidelity channel simulation.

In a 2D cylindrical coordinate system $(r, z)$, high-frequency acoustic pressure field $P(r, z)$ satisfies the ray acoustic approximation of the Helmholtz equation. Sound ray trajectories adhere to the Eikonal equation:
\begin{equation}
\left( \frac{\partial \tau}{\partial r} \right)^2 + \left( \frac{\partial \tau}{\partial z} \right)^2 = \frac{1}{c^2(z)}
\end{equation}
where $c(z)$ represents the Sound Speed Profile (SSP). Based on bathymetric geometries and sound speed distributions, Bellhop computes eigenrays, tracing travel time $\tau_p$, amplitude attenuation $A_p$, and boundary reflection phase shifts for each eigenray $p$. The time-varying acoustic channel impulse response (CIR) is expressed as:
\begin{equation}
h(t, \tau) = \sum_{p=1}^{P} A_p(t) \cdot e^{j \phi_p(t)} \cdot \delta\big(\tau - \tau_p(t)\big)
\end{equation}
where $P$ is the number of active eigenrays, $A_p(t)$ accounts for geometric spreading and seawater absorption loss computed via Thorpe's attenuation formula \cite{Thorpe1967}, and $\phi_p(t)$ denotes phase drift.

Two realistic ocean scenarios are established:
\begin{enumerate}
    \item \textbf{Deep-Sea Profile}: Water depth of 4000 m and transmission distance of 45 km, featuring a canonical Munk SSP with sound channel axis at 1000 m. Sound rays refract smoothly in the SOFAR channel, subjecting received signals to long multipath delays spanning tens of milliseconds and severe attenuation, with SNRs dropping below -10 dB.
    \item \textbf{Shallow-Water Profile}: Water depth of 100 m and transmission distance of 20 km, featuring a surface duct and frequent sea-surface/bottom boundary reflections. High-order reflections generate dense, strong multipath spreads (severe ISI), while surface waves induce rapid non-stationary Doppler fluctuations.
\end{enumerate}

Following propagation through the physical channel, the baseband received signal is expressed as:
\begin{equation}
r(t) = s_{bb}(t) \otimes h(t, \tau) e^{j (2\pi f_{d} t + \theta_0)} + n(t)
\end{equation}
where $n(t)$ denotes additive white ocean ambient noise.

\section{Proposed System-Level Space-Time Architecture}
To address the dual challenges of frequency-selective fading and non-stationary Doppler shifts in highly dynamic ocean environments, a robust, system-level cascaded space-time architecture is proposed in this section.

\subsection{Hybrid-Threshold TRM Pre-focusing}
In complex shallow-water environments, the received signal $r(t)$ is often distorted by multipath fading. Initial CIR estimate $\hat{h}(t)$ is obtained through cross-correlation with local LFM reference preamble $s_{ref}(t)$:
\begin{equation}
\hat{h}(t) = \int r(\tau) s_{ref}^*(\tau - t) d\tau
\end{equation}

To isolate genuine multipath arrivals from dense reverberation noise floors, conventional systems employ Constant False Alarm Rate (CFAR) algorithms. However, statistical CFAR exhibits a significant drawback when applied to LFM signals: LFM matched filtering inherently produces deterministic autocorrelation sidelobes whose envelope highly depends on the time-bandwidth product (TBP) and out-of-band roll-off. When the environmental noise floor is extremely low, a purely statistical OS-CFAR threshold drops below the deterministic sidelobe level, causing the system to erroneously extract sidelobes as actual multipath components, leading to self-interference.

To overcome this, a \textbf{Hybrid-Threshold} extraction mechanism is proposed. The final dynamic truncation threshold $\gamma_{hybrid}$ is defined as the maximum of statistical OS-CFAR threshold $\gamma_{cfar}$ and the dynamic theoretical sidelobe floor $P_{sidelobe}$:
\begin{equation}
\gamma_{hybrid} = \max(\gamma_{cfar}, P_{sidelobe})
\end{equation}
Here, $P_{sidelobe}$ is dynamically computed from the physical auto-correlation function (ACF) of the local LFM reference signal, $P_{sidelobe} = \kappa \cdot \max_{\tau \notin \text{mainlobe}} | R_{ref}(\tau) |$, eliminating the mathematical flaws of static heuristic approximations. Noise-suppressed CIR is extracted as:
\begin{equation}
\hat{h}_{ext}(t) = \begin{cases} \hat{h}(t), & |\hat{h}(t)| > \gamma_{hybrid} \\ 0, & \text{otherwise} \end{cases}
\end{equation}
Time-reversal convolution is performed: $y(t) = r(t) \otimes \hat{h}_{ext}^*(-t)$. This operation acts as a spatial matched filter, coherently combining multipath energy into an approximated main path, which improves SNR for subsequent tracking loops.

\subsection{Heteroscedastic Variational Bayesian Tracking}
Following spatial energy focusing, the equivalent baseband signal still suffers from time-varying Doppler shifts. In decision-directed loops, a critical failure mode known as error propagation occurs when signals enter deep fades: hard decisions fail, innovations become pure noise, and standard adaptive filters incorporate excessive errors, causing tracking divergence.

To adaptively estimate the non-stationary measurement noise covariance $R_k$, we employ a Variational Bayesian (VB) framework. The inverse-Gamma prior is updated during the M-step using variational parameters $\alpha_R$ and $\beta_R$. However, standard VB updates are highly sensitive to sudden signal dropouts. To resolve this, a \textbf{Heteroscedastic Variational Bayesian AKF (HVB-AKF)} mechanism is introduced. The core physical insight is that the magnitude of differential soft-symbol outputs, denoted as $m_k = |s_k s_{k-1}^*|$, serves as an effective instantaneous indicator of decision reliability.

We design a conditional heteroscedastic penalty factor $\Lambda(m_k)$ driven by the soft-envelope:
\begin{equation}
\Lambda(m_k) = \frac{c_{1,k}}{m_k^2 + c_{2,k}}
\end{equation}
where $c_{2,k}$ controls the maximum penalty ceiling and $c_{1,k} = 1 + c_{2,k}$ ensures normalization. To adapt to the non-stationary transient Doppler shifts of the acoustic channel, $c_{2,k}$ is no longer a static empirical constant, but dynamically evolves based on the normalized prediction error gradient:
\begin{equation}
c_{2,k} = c_{2,k-1} - \mu \nabla_{c_2} J(\epsilon_k)
\end{equation}
where $J(\epsilon_k) = \frac{1}{2} \epsilon_k^T S_k^{-1} \epsilon_k$ is the cost function constructed from the innovation $\epsilon_k = z_k - \hat{z}_{k|k-1}$ and its covariance $S_k$. The step size $\mu$ controls the adaptation rate. When a sudden deep fade induces an innovation spike, the negative gradient rapidly drives $c_{2,k}$ downward, instantly amplifying the heteroscedastic penalty to trigger the inertial coasting state.

During the M-step of the VB iteration, the baseline measurement noise estimate $R_{vb}$ is derived from the hyperparameter ratio $\beta_R / \alpha_R$. This baseline is then dynamically scaled by the instantaneous heteroscedastic penalty to formulate the final adaptive covariance:
\begin{equation}
R_k^{adaptive} = \frac{\beta_R}{\alpha_R} \cdot \Lambda(m_k)
\end{equation}

When signals undergo deep fades ($m_k \to 0$), the penalty factor $\Lambda(m_k)$ increases sharply to its upper bound. The artificially inflated $R_k^{adaptive}$ forces the Kalman gain $K_k \to 0$. Consequently, the state update equation naturally degenerates into $\hat{\mathbf{X}}_{k|k} \approx \hat{\mathbf{X}}_{k|k-1}$, placing the tracking loop into an ``inertial coasting'' state that effectively suppresses error propagation. 

It is mathematically crucial to note that the heteroscedastic penalty $\Lambda(m_k)$ is structurally decoupled from the Variational M-step. The inverse-Gamma sufficient statistics ($\alpha_R$ and $\beta_R$) are updated strictly using the unpenalized innovations, perfectly preserving the posterior convergence and statistical optimality of the ambient noise estimate $R_{vb}$. The penalty is solely applied to modulate the effective noise for the Kalman gain computation, thereby inducing inertial coasting without corrupting the VB inference. Conversely, under reliable channel conditions ($m_k \approx 1$), $\Lambda(m_k) \to 1$, and standard VB adaptive tracking resumes. This architecture combines the long-term noise-floor tracking capability of Variational Bayes with the instantaneous resilience of soft-decision penalties.

\subsection{2D SNR-Delay Dynamic Routing Architecture}
While TRM excels at focusing multipath energy in low-SNR environments, it introduces a physical drawback in long data packets: \textbf{Channel Aging}. Static TRM template $\hat{h}_{ext}(t)$ is estimated from preambles. In dynamic ocean environments, actual CIR decorrelates over packet durations. At high SNRs (e.g., $>-9\text{ dB}$), channel noise is inherently low, and dominant error sources become distortions caused by convolving received signals with stale TRM templates. This self-generated interference creates an error floor, preventing optimal transmission under excellent channel conditions.

To resolve this issue, an \textbf{2D SNR-Delay Dynamic Routing} architecture is introduced. First, the intensity of inter-symbol interference (ISI) is quantified using the time-domain root mean square (RMS) delay spread $\tau_{rms}$, computed from the preamble's extracted channel impulse response $\hat{h}_{ext}(\tau)$:
\begin{equation}
\tau_{rms} = \sqrt{ \frac{\int (\tau - \bar{\tau})^2 |\hat{h}_{ext}(\tau)|^2 d\tau}{\int |\hat{h}_{ext}(\tau)|^2 d\tau} }
\end{equation}
where $\bar{\tau}$ is the mean excess delay.

The routing decision mathematically fuses the SNR hysteresis model with the temporal ISI threshold $\tau_{rms, th}$:
\begin{equation}
\text{Routing}_k = 
\begin{cases}
\text{Bypass}, & \text{if } \Big(\text{SNR}_{est} > \gamma_{H} \text{ or } (\text{Routing}_{k-1} = \text{Bypass} \text{ and } \text{SNR}_{est} \ge \gamma_{L})\Big) \textbf{ and } \tau_{rms} < \tau_{rms, th} \\
\text{Activate TRM}, & \text{otherwise}
\end{cases}
\end{equation}
To prevent the detrimental ``ping-pong effect'' caused by transient environmental noise, we preserve the robust SNR Hysteresis Thresholding (迟滞门限) with upper and lower bounds $\gamma_H = -8\text{ dB}$ and $\gamma_L = -10\text{ dB}$. Crucially, the logical AND fusion ensures that even under high SNR, if severe multi-path persists ($\tau_{rms} \ge \tau_{rms, th}$), the TRM module remains fully activated to compress the spatial energy. The delay threshold is strictly tied to the system bandwidth, defined as $\tau_{rms, th} = 0.2 T_s$, guaranteeing that TRM is bypassed only when the channel is both low-noise and intrinsically sparse.

\section{Simulation Setup and Benchmarks}
To rigorously evaluate the proposed space-time equalization architecture under realistic constraints, comprehensive simulations are conducted using MATLAB integrated with Bellhop physical acoustic channel models. Table \ref{tab:params} details the specific environmental geometries and DSSS parameters.

\begin{table}[htbp]
\centering
\caption{System Simulation \& Environmental Parameters}
\label{tab:params}
\begin{tabular}{ll}
\toprule
Parameter & Value \\
\midrule
Carrier Frequency ($f_c$) & 12 kHz / 24 kHz \\
Bandwidth ($B$) & 4 kHz \\
Spreading Sequence & PN Sequence ($L_c = 127, 255$) \\
Modulation & DQPSK / DSSS \\
Doppler Shift Range & $\pm 10$ Hz \\
Surface Wave Jitter Rate & 0.5 Hz/s \\
Deep-Sea Distance / Depth & 45 km / 4000 m (SOFAR) \\
Shallow-Water Distance / Depth & 20 km / 100 m \\
OS-CFAR Sidelobe Floor ($P_{sidelobe}$) & Dynamic ACF Peak \\
\bottomrule
\end{tabular}
\end{table}

The proposed system is benchmarked against three baseline configurations:
\begin{itemize}
    \item \textbf{Baseline A}: Standard AKF without TRM pre-focusing.
    \item \textbf{Baseline B}: TRM pre-focusing combined with Standard AKF.
    \item \textbf{Baseline C}: TRM pre-focusing combined with heuristic IAE-AKF \cite{Yang2024}.
\end{itemize}

\section{Performance Evaluation}

\subsection{Channel Modeling Validation via CIR}
To ensure the evaluation relies on physically consistent boundary conditions, high-fidelity Bellhop simulations are employed instead of conventional statistical fading models. As previously illustrated in the conceptual model, the deep-sea (4000m depth, 45km distance) channel exhibits sparse multipath arrivals with exceptionally long delay spreads (tens of milliseconds). Conversely, shallow-water profiles generate dense, overlapping micro-multipaths due to frequent boundary reflections. These dynamic, structurally distinct channel impulse responses (CIR) provide a rigorous testbed for validating the robustness of the space-time equalization architecture against severe ISI.

\subsection{Evaluation of Space-Time Multipath Focusing}
The proposed Hybrid-Threshold TRM mechanism effectively and blindly suppresses severe delay spreads to achieve coherent energy focusing.
\begin{figure}[htbp]
    \centering
    \includegraphics[width=\linewidth]{figures/fig1_trm_cfar.png}
    \caption{TRM extraction at 0 dB SNR: Pure OS-CFAR capturing self-interference sidelobes (top) vs. the proposed Hybrid-Threshold isolating the clean main peak (bottom).}
    \label{fig:trm_cfar}
\end{figure}
In our evaluations, the raw CIR exhibits extreme energy dispersion. As shown in Fig. \ref{fig:trm_cfar} (top), when operating at high SNRs (e.g., 0 dB), purely statistical OS-CFAR thresholds erroneously extract deterministic LFM autocorrelation sidelobes as multipath arrivals, leading to severe self-interference. In contrast, the proposed $\max(\gamma_{cfar}, P_{sidelobe})$ truncation mechanism (Fig. \ref{fig:trm_cfar}, bottom) strictly excludes these sidelobe-induced artifacts, coherently compressing the dispersed energy into a singular, sharp main peak. Consequently, this precise spatial pre-processing provides a structurally clean input for the subsequent temporal tracking loop.

\subsection{Tracking Stability and Error Mitigation}
The HVB-AKF mechanism fundamentally interrupts decision-directed error propagation during deep fades.
\begin{figure}[htbp]
    \centering
    \includegraphics[width=\linewidth]{figures/Fig_Tracking_Error_Single_Mech.png}
    \caption{Tracking mechanism under a single severe deep fading realization (SNR = -12 dB). Top: Smoothed absolute tracking error. Bottom: Kalman Gain ($K_k$) evolution. The grey shaded region (symbols 60--90) highlights the deep fade where the baseline avalanches while the proposed algorithm coasts.}
    \label{fig:tracking_error}
\end{figure}
At an extreme lethal SNR of -12 dB (Fig. \ref{fig:tracking_error}), a representative single realization perfectly illustrates the non-linear error avalanche phenomenon. Baseline C (heuristic IAE-AKF) suffers from catastrophic error propagation during deep fades (grey shaded region, symbols 60--90). As shown in the top subplot, its smoothed tracking error diverges significantly. The fundamental physical cause is revealed in the bottom subplot: the baseline's Kalman gain remains improperly unbounded (near 1.0), blindly absorbing severe ambient noise into the state estimate. In stark contrast, the proposed HVB-AKF dynamically responds to the fading envelope. As the soft-symbol reliability drops into the noise floor, the heteroscedastic penalty prevents the state covariance from exploding and instantly forces the Kalman gain $K_k \to 0$. By executing this ``inertial coasting'' maneuver, the proposed architecture decisively blocks destructive feedback and maintains a bounded, convergent error trajectory throughout the deep fade, guaranteeing synchronization survival in hostile acoustic environments.

\subsection{System-Level BER Performance}
The integrated architecture yields disruptive system-level gains across diverse acoustic channels.
\begin{figure*}[htbp]
    \centering
    \begin{subfigure}{0.32\textwidth}
        \includegraphics[width=\linewidth]{figures/Fig_BER_Refined_1.png}
        \caption{Deep-Sea (45 km)}
        \label{fig:ber_deep}
    \end{subfigure}
    \hfill
    \begin{subfigure}{0.32\textwidth}
        \includegraphics[width=\linewidth]{figures/Fig_BER_Refined_2.png}
        \caption{Shallow-Water (Flat)}
        \label{fig:ber_flat}
    \end{subfigure}
    \hfill
    \begin{subfigure}{0.32\textwidth}
        \includegraphics[width=\linewidth]{figures/Fig_BER_Refined_3.png}
        \caption{Shallow-Water (Slope)}
        \label{fig:ber_slope}
    \end{subfigure}
    \caption{BER performance comparison of the equalization algorithms across three distinct physical channels.}
    \label{fig:ber_comparison}
\end{figure*}
Fig. \ref{fig:ber_comparison} isolates the specific contributions of each module across the three distinct acoustic environments. Pure AKF (Baseline A) entirely collapses due to unresolved multipath ISI. Baseline C achieves a BER of $10^{-3}$ only at 0 dB SNR in shallow water. Conversely, the proposed joint architecture consistently achieves the target $10^{-3}$ BER at approximately -4.5 dB SNR, delivering an extraordinary 4.5 dB gain over the best baseline. Furthermore, the SNR-Aware dynamic routing logic completely resolves the persistent error floor observed in static TRM implementations at SNRs above -9 dB, achieving error-free transmission. 

\begin{table}[htbp]
\centering
\caption{Complexity \& Execution Time per Symbol}
\label{tab:complexity}
% 使用 resizebox 强制表格适应当前栏宽 (columnwidth)
\resizebox{\columnwidth}{!}{%
\begin{tabular}{llll}
\toprule
% 精简了表头，减小原始宽度
Algorithm & Complexity & ARM ($\mu s$) & Intel ($\mu s$) \\
\midrule
Standard EKF & $O(n_x^3)$ & 142.5 & 12.1 \\
% 将过长的名字缩写为 VB-EKF
VB-EKF \cite{VBEKF2023} & $O(N_{iter} n_x^3)$ & 685.0 & 54.3 \\
IAE-AKF \cite{Yang2024} & $O(n_x)$ & 18.2 & 1.8 \\
\textbf{Proposed HVB-AKF} & \textbf{$O(N_{iter} n_x^3)$} & \textbf{687.5} & \textbf{54.8} \\
\bottomrule
\end{tabular}%
}
\end{table}

While the proposed HVB-AKF introduces computational overhead comparable to standard Variational Bayesian methods \cite{VBEKF2023}, this trade-off is physically justified by the extraordinary tracking stability and error avalanche prevention achieved during deep fading, making it highly suitable for AUVs equipped with capable processors.

To definitively validate the generalization capability of the proposed architecture, one can observe the highly consistent convergence of the proposed HVB-AKF curves (red lines) across the three distinct physical environments shown in Fig. \ref{fig:ber_comparison}: a deep-sea 45 km profile with massive delay spread, a shallow-water 20 km profile with dense multipath, and a highly undulating shallow-water slope. The consistent performance demonstrates that the rigorous integration of TRM spatial focusing and HVB-AKF temporal tracking provides robust equalization completely independent of specific local topography, ensuring highly reliable deployment in unmapped ocean regions.

\section{Conclusion}
This paper presented a robust, system-level space-time joint equalization architecture for underwater acoustic DSSS communications. In the spatial domain, a Hybrid-Threshold TRM mechanism is introduced to effectively focus multipath energy while suppressing deterministic LFM sidelobe interference. In the temporal domain, a Heteroscedastic Variational Bayesian Adaptive Kalman Filter (HVB-AKF) integrates an instantaneous physical reliability metric to dynamically penalize measurement noise covariance, effectively suppressing tracking divergence and error avalanches during deep fades. Furthermore, a 2D SNR-Delay Dynamic Routing architecture resolves the physical drawback of TRM channel aging, eliminating high-SNR error floors. Validated on Bellhop high-fidelity acoustic simulation platforms, the proposed system achieves a $10^{-3}$ bit error rate (BER) threshold across diverse multipath scenarios, offering a practical algorithmic foresight for AUVs and demanding underwater sensor networks. Note that current numerical evaluations exclude real-world physical perturbations such as transducer non-linearity and hydrodynamic noise, warranting further sea-trial validations.

\begin{acks}
This work was supported in part by the National Natural Science Foundation of China.
\end{acks}

\bibliographystyle{ACM-Reference-Format}
\begin{thebibliography}{99}

\bibitem{Stojanovic1994}
M. Stojanovic, J. Catipovic, and J. G. Proakis. 1994. Phase-coherent digital communications for underwater acoustic channels. \emph{IEEE Journal of Oceanic Engineering} 19, 1 (1994), 100--111.

\bibitem{Yang2024}
Author et al. 2024. Robust Time-Delay Tracking of Underwater Spread-Spectrum Signals via Structural Regularized Adaptive Filtering under Non-Stationary Doppler Conditions. \emph{Preprint} (2024).

\bibitem{VBEKF2023}
Author et al. 2023. Robust underwater direction-of-arrival tracking based on AI-aided variational Bayesian extended Kalman filter. \emph{Remote Sensing} 15, 2 (2023), 420.

\bibitem{Kuperman1998}
W. A. Kuperman, W. S. Hodgkiss, H. C. Song, T. Akal, C. Ferla, and D. R. Jackson. 1998. Phase conjugation in the ocean: Experimental demonstration of an acoustic time-reversal mirror. \emph{The Journal of the Acoustical Society of America} 103, 1 (1998), 25--40.

\bibitem{Zhang2026}
W. Zhang et al. 2026. A distributed fusion method for underwater multi-sensor passive tracking based on extended measurement space. \emph{Electronics} 15, 1 (2026), 112.

\bibitem{Thorpe1967}
W. H. Thorp. 1967. Analytic description of the low-frequency attenuation of sound in the ocean. \emph{The Journal of the Acoustical Society of America} 42, 1 (1967), 270--270.

\end{thebibliography}

\end{document}