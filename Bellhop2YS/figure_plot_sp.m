% clear; 
close all;
figure,
%% 绘制声速梯度
figure
plot(soundspeeds(:, 2), soundspeeds(:, 1),'r', 'LineWidth',2.5); axis ij;
xlabel('C(m/s)');
ylabel('Deep(m)');
set(gca,'xaxislocation','top');
% set(gca,'YDir','reverse');
grid on; grid minor;

%% 绘制声速剖面
figure
plotray channel_E, hold on;
scatter(0, 15, 'rx')

%% 绘制传播损失
% subplot(3, 4, [6, 7, 8]);
% plotshd channel_C.shd

%% 绘制信道冲激响应
figure
stem(delay, Amplitude, 'k', 'LineWidth',1.5);
title('Channel impulse response '); xlabel('Times(s)'); ylabel('Amplitude');
grid on; grid minor;

