# 系统理论依据与算法推导备忘录 (System Architecture & Theory)

本文档补充详细说明本项目在水声通信时变多普勒与强多径干扰下的核心物理与理论推导，作为科研论文撰写、结题报告及系统拓展的理论支撑。

---

## 一、 水下非平稳时变多普勒信道映射模型

设水下收发节点间由于潜水器机动、波浪推挽及水流湍流产生的瞬时相对运动速度为 $v(t)$：
$$v(t) = v_0 + a_0 t + A_{wave} \sin(2\pi f_{wave} t + \phi) + v_{turb}(t)$$
其中：
- $v_0$ 为宏观初始径向速度；
- $a_0$ 为恒加速度机动分量；
- $A_{wave}, f_{wave}$ 为海面推挽波浪震荡造成的周期性速度变化；
- $v_{turb}(t)$ 对应的离散化湍流扰动速度序列 $v_{turb}[k]$ 符合一阶自回归 $AR(1)$ 方程：$v_{turb}[k] = \rho v_{turb}[k-1] + w[k]$。

水下声速设为 $c$，则连续多普勒重采样尺度因子为：
$$\alpha(t) = 1 + \frac{v(t)}{c}$$
由于 $\alpha(t)$ 非平稳随时间快速变化，发送信号 $x(t)$ 经过时变多普勒拉伸与水下稀疏多途信道 $h_{uwa}(\tau, t)$ 后的接收信号 $y(t)$ 满足：
$$y(t) = \sum_{l=1}^{L} A_l(t) x\left( \int_0^{t-\tau_l} \alpha(u) du \right) + n(t)$$

---

## 二、 自适应新息卡尔曼滤波时延锁相环 (IAKF-DLL)

为了在未知的时变多普勒下精准追踪扩频码片的亚采样级偏移，构造基于超前-滞后 (Early-Late) 相关器的鉴相器，其非相干归一化鉴相误差 $Z_n$ 定义为：
$$Z_n = \frac{E_{pwr} - L_{pwr}}{E_{pwr} + L_{pwr} + \epsilon}$$
其中 $E_{pwr}, L_{pwr}$ 为超前与滞后 $\Delta$ 个采样的多周期相关能量。状态向量定义为 $\mathbf{X}_k = [\Delta \tau_k, \dot{\Delta \tau}_k]^T$，即相位偏移与多普勒变化率。

卡尔曼估计方程组：
1. **先验状态预测**：$\mathbf{X}_{k|k-1} = \mathbf{F} \mathbf{X}_{k-1}$
2. **先验协方差预测**：$\mathbf{P}_{k|k-1} = \mathbf{F} \mathbf{P}_{k-1} \mathbf{F}^T + \mathbf{Q}_k$
3. **滑动窗口新息计算**：$\gamma_k = y_k - \mathbf{H} \mathbf{X}_{k|k-1} = Z_n \cdot \Delta$

### 自适应新息估计 (IAE, Innovation Adaptive Estimation)
通过计算大小为 $W_{size}$ 窗口内新息序列方差 $C_k = \frac{1}{W_{size}} \sum_{i=0}^{W_{size}-1} \gamma_{k-i}^2$，反向在线解算协方差矩阵：
$$\hat{\mathbf{R}}_k = C_k - \mathbf{H} \mathbf{P}_{k|k-1} \mathbf{H}^T$$
其中 $\hat{\mathbf{Q}}_k$ 取矩阵 $\mathbf{K}_k C_k \mathbf{K}_k^T$ 的主对角元素构成的对角阵，
并采用一阶指数平滑更新：
$$\mathbf{R}_k = \max(0.01, 0.8\mathbf{R}_{k-1} + 0.2\hat{\mathbf{R}}_k)$$
$$\mathbf{Q}_k = \max(1\times 10^{-4}, 0.9\mathbf{Q}_{k-1} + 0.1\hat{\mathbf{Q}}_k)$$

---

## 三、 TRM 时间反转镜盲聚焦与差分调制解调原理

由于系统采用差分编码 $d_c(n) = b(n) d_c(n-1)$，通过 Kronecker 张量扩频生成发射序列。在经历横跨数十码片的多径信道 $h(t)$ 后，传统接收器难以直接解调。

1. **盲估计 TRM 时间反转预均衡**  
   利用同步前导 HFM 信号自相关特性匹配得到信道冲激响应估计 $\hat{h}(t)$，构造反向翻转滤波器 $h_{TR}(t) = \hat{h}^*(-t)$。信号通过预聚焦滤波器后等效经历：
   $$h_{eff}(t) = h(t) * h_{TR}(t) \approx \delta(t) + \text{sidelobes}$$
   主尖峰能量高度集中，自适应消解大部分码间干扰 (ISI)。

2. **全局残差相漂补偿块差分解调**  
   对于解扩软输出序列 $s(n)$，在计算差分向量 $D(n) = s(n+1) s^*(n)$ 后，整体相位偏移估计由二阶无偏相角求得：
   $$\hat{\theta}_{drift} = \frac{1}{2} \arg\left( \sum_{n=1}^{N_{sym}} D^2(n) \right)$$
   最终无偏判决变量为：
   $$\hat{b}(n) = \text{sign}\left( \Re\left\{ D(n) e^{-j\hat{\theta}_{drift}} \right\} \right)$$
