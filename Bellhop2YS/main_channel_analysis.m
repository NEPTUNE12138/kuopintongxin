%% 深海信道特性分析主程序
%% JYZ 2026.4.16

clc; clear; 
close all;
 
%% ========== 参数设置（每次修改这里） ==========
freq    = 3e3;    % 仿真频率 (Hz) % 会聚区3e3 声道轴5e3
Source_depth  = 100;    % 声源深度 (m)
Rcr_depth   = 110;    % 接收深度 (m) (当需要画单个点时，就是接收深度，画范围的时候就是步长)
range   = 45;     % 水平距离 (km)
rstep   = 20;     % 水平方向步长 (m)
Nbeams  =1000;   % 声线数目
Sea_depth = 4325; % 海深 (m)
Speed_seafloor = 1542.6; % 海底声速 1540 (m/s)
ssp_file = 'SSP_202305.mat';  % 声速剖面文件

% freq    = 5e3;    % 仿真频率 (Hz) % 会聚区3e3 声道轴5e3
% Source_depth  = 1100;    % 声源深度 (m)
% Rcr_depth   = 1186;    % 接收深度 (m) (当需要画单个点时，就是接收深度，画范围的时候就是步长)
% range   = 50;     % 水平距离 (km)
% rstep   = 20;     % 水平方向步长 (m)
% Nbeams  = 1000;   % 声线数目
% Sea_depth = 4278; % 海深 (m)
% Speed_seafloor = 1540; % 海底声速 1540 (m/s)
% ssp_file = 'SSP_202406.mat';  % 声速剖面文件

%% ========== 声速剖面处理 ==========
soundspeeds_ori = importdata(ssp_file);
[~, pos]  = max(soundspeeds_ori(:, 1));
[~, pos2] = min(soundspeeds_ori(:, 2));

index1 = 1 : 1 : 500;
index2 = 500 : 3 : pos;
soundspeeds = [soundspeeds_ori(index1, :); soundspeeds_ori(index2, :)];

figure;
plot(soundspeeds_ori(:, 2), soundspeeds_ori(:, 1), 'k', 'LineWidth', 1.5); hold on;
scatter(soundspeeds_ori(16, 2), soundspeeds_ori(16, 1), 'rx');

% scatter(soundspeeds_ori(pos2, 2), soundspeeds_ori(pos2, 1), 'xr', 'LineWidth', 1.5);
axis ij; grid on; grid minor;
xlabel(''); ylabel('');
axis([1480 1550 0 4325]);
set(gca, 'xaxislocation', 'top', 'FontName', 'Times New Roman', 'FontSize', 14);
box on;

[depth_sort, index] = sort(soundspeeds(:, 1));
speed_sort = soundspeeds(index, 2);
soundspeeds_sort = [[depth_sort.', Sea_depth].', [speed_sort.', Speed_seafloor].'];% 202305

%% ========== 生成.env文件 ==========
Type = ['A', 'E', 'C', 'R'];
R_OR_S = 'S';
for num = 1 : length(Type)
    outFileName = ['channel_', Type(num)];
    Runoption   = Type(num);
    bellhopENVgen(soundspeeds_sort, freq, outFileName, Source_depth, Rcr_depth, ...
                  range, rstep, Nbeams, Runoption, R_OR_S, Sea_depth, Speed_seafloor);
end
%% ========== 运行Bellhop - 声线 ==========
global units; units = 'km';
% 
% bellhop channel_R
% figure;
% plotrayR('channel_R', Rcr_depth); hold on;
% scatter(0, Source_depth, 'rx');
% grid on; grid minor; title(''); xlabel(''); ylabel('');
% set(gca, 'FontName', 'Times New Roman', 'FontSize', 14);
% box on;

% %%% 影区用
% x = [10, 20];
% y = [408 1091 2230 3467];
% for numx = 1 : length(x)
%     for numy = 1 : length(y)
%         scatter(x(numx), y(numy), 250, 'p', 'filled', ...
%     'MarkerFaceColor', [1 0.9 0], ...
%     'MarkerEdgeColor', 'k', ...
%     'LineWidth', 1.5)
%     end
% end

%% ========== 运行Bellhop - 本征声线 ==========
% 
bellhop channel_E
figure;
plotray('channel_E', Rcr_depth); hold on; 
scatter(0, Source_depth, 'rx');
grid on; grid minor; title(''); xlabel(''); ylabel('');
set(gca, 'FontName', 'Times New Roman', 'FontSize', 14);
box on;
%% ========== 运行Bellhop - 传播损失（可选） ==========
if R_OR_S == 'R'
    bellhop channel_C
    figure; plotshd channel_C.shd
    set(gca, 'FontName', 'Times New Roman', 'FontSize', 14);
    title(''); xlabel(''); ylabel(''); 
    axis([0 30 0 4278]);
    figure; plottlr('channel_C.shd', 1813); hold on;
    plottlr('channel_C.shd', 4000);
end

%% ========== 运行Bellhop - 到达结构 ==========
bellhop channel_A
load valid_angles.mat
[Arr, Pos] = read_arrivals_asc('channel_A.arr');

%% ========== 筛选有效到达 ==========
Narr = Arr.Narr;
SrcAngle_range  = Arr.SrcAngle(1:Narr);
RcvrAngle_range = Arr.RcvrAngle(1:Narr);
Amp_range       = Arr.A(1:Narr);
Delay_range     = Arr.delay(1:Narr);
NumTopBnc_range = Arr.NumTopBnc(1:Narr);
NumBotBnc_range = Arr.NumBotBnc(1:Narr);

% 根据画图时保存的发射角匹配
valid = false(Narr, 1);
for k = 1:length(valid_src_angles)
    [diff_min, idx] = min(abs(SrcAngle_range - valid_src_angles(k)));
    if diff_min < 0.5
        valid(idx) = true;
    end
end

% 提取筛选后的字段
amp_clean         = Amp_range(valid);
amp_clean_complex = Amp_range(valid);
delay_clean       = Delay_range(valid);
SrcAngle_clean    = SrcAngle_range(valid);
RcvrAngle_clean   = RcvrAngle_range(valid);
NumTopBnc_clean   = NumTopBnc_range(valid);
NumBotBnc_clean   = NumBotBnc_range(valid);
amp_norm          = abs(amp_clean) / max(abs(amp_clean));

%% ========== 保存数据 ==========
save_name = sprintf('channel_%dm_%dkm_%dm.mat', Source_depth, range, Rcr_depth);
save(save_name, 'delay_clean', 'amp_clean', 'amp_clean_complex', ...
     'SrcAngle_clean', 'RcvrAngle_clean', ...
     'NumTopBnc_clean', 'NumBotBnc_clean', 'amp_norm');
fprintf('数据已保存: %s\n', save_name);

%% ========== 声线类型统计 ==========
n_refract = sum(NumTopBnc_clean == 0 & NumBotBnc_clean == 0);
n_bot     = sum(NumTopBnc_clean == 0 & NumBotBnc_clean >= 1);
n_top     = sum(NumTopBnc_clean >= 1 & NumBotBnc_clean == 0);
n_both    = sum(NumTopBnc_clean >= 1 & NumBotBnc_clean >= 1);

fprintf('\n========== 声线统计 ==========\n');
fprintf('纯折射声线: %d 条\n', n_refract);
fprintf('纯海底反射声线: %d 条\n', n_bot);
fprintf('纯海面反射声线: %d 条\n', n_top);
fprintf('海面-海底反射声线: %d 条\n', n_both);
fprintf('合计: %d 条\n', length(delay_clean));

%% ========== 绘制3D分析图 ==========
figure_plot_channel_angle_amp_3D(SrcAngle_clean, delay_clean, amp_norm, ...
                                  NumTopBnc_clean, NumBotBnc_clean);

%% ========== 绘制2D投影图 ==========
figure_plot_channel_delay_amp_2D(delay_clean, amp_norm, ...
                                  NumTopBnc_clean, NumBotBnc_clean);