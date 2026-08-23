# Bellhop2YS 水声信道仿真与声线特征分析系统

`Bellhop2YS` 是一个基于 **Bellhop 声学射线追踪模型** 与 **MATLAB** 的水声信道仿真与分析平台。系统能够根据海洋声速剖面（SSP）、海水深度、底质声学参数及声源/接收器位置，自动构建 Bellhop 环境配置文件，调用计算引擎仿真声脉冲到达结构、特征声线轨迹与传播损失，并完成多径传播声线的分类统计、筛选与 2D/3D 可视化分析。

仿真导出的水声信道冲激响应（CIR）数据可直接用于扩频通信（如 DSSS、FHSS）系统的信道建模与误码率性能评估。

---

## 🌟 主要功能特性

1. **自动化 Bellhop 环境配置 (`.env`) 生成**
   - 通过 [`bellhopENVgen.m`](file:///e:/大学/科创/扩频通信/Bellhop2YS/Bellhop2YS/bellhopENVgen.m) 自动将声速剖面数据 (`.mat`)、海底声速、介质密度、边界条件与声线束参数格式化写入 Bellhop 引擎支持的 `.env` 配置文件。

2. **多模式声场仿真与计算**
   - **到达结构仿真（Arrivals, `channel_A`）**：计算多径声线的到达时延、幅度、相位、发射角、接收角及边界反射次数。
   - **特征声线追踪（Eigenrays, `channel_E`）**：计算并绘制连接声源与接收水听器的所有特征声线传播路径。
   - **传播损失场（Coherent TL, `channel_C`）**：分析特定频段下的声场空间传播损失。

3. **多径声线分类与统计分析**
   - 自动识别声线传播类型并分类统计：
     - 🌊 **直达波 / 折射波 (Direct/Refracted)**：无海面和海底反射 (`NumTopBnc == 0 & NumBotBnc == 0`)
     - 🌊 **海面反射波 (Surface Bounce)**：仅海面反射 (`NumTopBnc >= 1 & NumBotBnc == 0`)
     - 🐚 **海底反射波 (Bottom Bounce)**：仅海底反射 (`NumTopBnc == 0 & NumBotBnc >= 1`)
     - 🔄 **海面-海底混合反射波 (Top-Bottom Bounce)**：经历多次海面与海底反射

4. **角度筛选与数据导出**
   - 支持结合 [`valid_angles.mat`](file:///e:/大学/科创/扩频通信/Bellhop2YS/Bellhop2YS/valid_angles.mat) 过滤主声束发射角，剔除无效杂散声线。
   - 自动将清洗后的时延、复幅度、发射角、接收角及反射次数导出为 `.mat` 数据矩阵（如 `channel_100m_45km_110m.mat`）。

5. **丰富的 2D / 3D 可视化绘图**
   - **3D 散点/茎状图**：展现 **发射角 - 到达时延 - 归一化幅度** 关系，并标注反射次数标签（`(海面次数, 海底次数)`）。
   - **2D 信道冲激响应图**：绘制归一化幅度与到达时延茎状图，直观对比直达径与多径反射。
   - **轨迹与声速剖面图**：支持声速剖面图、声线轨迹图 (`plotray`) 及传播损失图 (`plotshd`)。

---

## 📁 目录结构

```text
Bellhop2YS/
├── main_channel_analysis.m            # 仿真主控脚本（参数配置、计算调度、统计与绘图）
├── bellhopENVgen.m                    # Bellhop 环境配置文件 (.env) 自动生成函数
├── bellhop.exe                        # Bellhop 声学射线追踪计算引擎 (Windows Executable)
├── bellhop.m                          # MATLAB 调用 bellhop.exe 的接口封装
├── read_arrivals_asc.m                # ASCII 格式 Arrival 文件 (.arr) 解析函数
├── read_shd.m / read_shd_bin.m        # 传播损失文件 (.shd) 数据读取函数
├── figure_plot_channel_angle_amp_3D.m # 3D 声线角度-时延-幅度可视化函数
├── figure_plot_channel_delay_amp_2D.m # 2D 信道冲激响应可视化函数
├── figure_plot_sp.m                   # 声速剖面绘图辅助脚本
├── plotray.m / plotrayR.m             # 声线轨迹绘制工具
├── plotshd.m                          # 传播损失图绘制工具
├── plotarr.m                          # 到达结构绘图工具
├── caxisrev.m                         # 颜色轴反转辅助工具
├── SSP_202305.mat                     # 实测/水文声速剖面数据
├── valid_angles.mat                   # 有效发射角度筛选阈值矩阵
└── channel_*.mat                      # 导出的水声信道参数结果数据
```

---

## ⚙️ 环境要求

- **MATLAB**：R2018b 或更高版本（需安装 Signal Processing Toolbox）
- **操作系统**：Windows 10 / Windows 11（用于直接运行目录下的 `bellhop.exe`）

---

## 🚀 快速开始

### 1. 设置工作路径
启动 MATLAB，将工作路径切换至包含代码的目录：
```matlab
cd('e:/大学/科创/扩频通信/Bellhop2YS/Bellhop2YS');
```

### 2. 配置仿真参数
在 [`main_channel_analysis.m`](file:///e:/大学/科创/扩频通信/Bellhop2YS/Bellhop2YS/main_channel_analysis.m) 中设置所需的环境与信号参数：

```matlab
freq           = 3e3;            % 中心频率 (Hz)
Source_depth   = 100;            % 发射声源深度 (m)
Rcr_depth      = 110;            % 接收水听器深度 (m)
range          = 45;             % 传播距离 (km)
rstep          = 20;             % 水平方向步长 (m)
Nbeams         = 1000;           % 发射声线束数量
Sea_depth      = 4325;           % 水深 (m)
Speed_seafloor = 1542.6;         % 底质声速 (m/s)
ssp_file       = 'SSP_202305.mat'; % 声速剖面数据文件
```

### 3. 运行仿真
在 MATLAB 命令行中运行主脚本：
```matlab
main_channel_analysis
```

### 4. 输出结果说明
运行完成后，控制台将输出多径声线分类统计信息，并自动生成绘图窗口：
```text
已保存: channel_100m_45km_110m.mat

========== 声线统计 ==========
直达/折射声线: 1 条
海底反射声线: 2 条
海面反射声线: 0 条
海面-海底混合反射声线: 3 条
合计: 6 条
```

同时在目录下生成导出的信道数据矩阵文件 `channel_100m_45km_110m.mat`，包含以下变量：
- `delay_clean`: 到达时延向量 (s)
- `amp_clean`: 导出的到达复幅度向量
- `amp_norm`: 归一化幅度向量
- `SrcAngle_clean` / `RcvrAngle_clean`: 发射角与接收角向量 (度)
- `NumTopBnc_clean` / `NumBotBnc_clean`: 海面与海底反射次数

---

## 📊 可视化效果示例

1. **声速剖面与折射分析**：解析海深方向上的声速变化梯度，定位深海声通道或浅海混合层。
2. **特征声线轨迹 (`channel_E`)**：清晰展现直达声线、一次底跳、海面-海底折反射声线的几何路径。
3. **3D 声线分布图**：以不同的 Marker 形状与颜色区分折射波、底反射、顶反射及多次混合反射，并在对应脉冲上方标注 `(TopBnc, BotBnc)`。

---

## 🛠️ 常见问题 (FAQ)

- **Q1: 运行时报错 `bellhop.exe` 权限拒绝或找不到可执行文件？**
  - 请确认运行环境为 Windows 系统，并且 MATLAB 具有调用当前目录下可执行文件的权限。若在 Linux/macOS 下使用，需替换为对应平台编译的 `bellhop` 二进制文件。

- **Q2: 导出的 Arrivals 数据为空？**
  - 请检查 `Source_depth` 与 `Rcr_depth` 是否超出了声速剖面或海深 `Sea_depth` 范围，或尝试增大发射角范围与声线束数量 `Nbeams`。

---

## 📜 许可证与致谢

- 本项目基于 [Acoustics Toolbox](http://oalib.hds.org/) 的 Bellhop 声学模型开发。
- 适用于水声通信、扩频通信、声学定位及水下多径信道建模等科研与教学项目。
