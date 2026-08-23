function [ SignalPsk ] = ModulateToCarrier( fs , f0 , SignalI , SignalQ )
% 函数功能：IQ相位调制
% 输入：
% fs：采样率
% f0：中心频率
% SignalI：I路信息
% SignalQ：Q路信息

% 输出：
% SignalPsk：调制到载波的信号

t = 0 : 1/fs : length(SignalI)/fs-1/fs;
Ysin = sin(2*pi*f0*t);%%+pi/4*ones(1,length(t))
Ycos = cos(2*pi*f0*t);
SignalPsk = SignalI .* Ycos + SignalQ .* Ysin;

end

%% 详解在 https://blog.csdn.net/wing_man/article/details/124243610?spm=1001.2014.3001.5506

