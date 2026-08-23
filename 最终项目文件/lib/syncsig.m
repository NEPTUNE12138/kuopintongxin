function[sync] = syncsig(pw,f1,f2,fs,type,varargin)
%函数功能：生成LFM/HFM信号
%pw:脉宽
%fl:起始频率
%fh:终止频率
%fs:采样率
%type：1为LFM信号，2为HFM信号
%varargin：1输出信号的频谱图，2输出信号的时频图
%SYNCSIG:Generate a synchronization signal:Type 1:Chirp signal;Type
%2:Hyperbolic FM signal.
%Sync = SYNCSIG(pw,fh,fl,fs,type,varargin)
% INPUT：
% 'pw'：Length of the synchronization signal which you want to generate.   /s
% 'fs'：Signal sampling rate.                                              /Hz
% 'type'：The type of synchronization signal you want to generate          1/2
%      when type == 1,generate a chirp signal;
%      when type == 2,generate a Hyperbolic FM signal.
% Other types do not have optional input parameters.
% You can input onemore parameter'1' if you want to plot amplitude
% spectrum,'2'if you want to plot time-frequency curve.
% OUTPUT：
% 'sync'：A synchronization signal.
    t=0:1/fs:pw-1/fs;  
    if type==1
%         k=(f1-f2)/pw;
%         sync = 0.8*cos(2*pi*f2*t+pi*k*t.^2);                               %chirp signal    
        sync = chirp(t,f1,pw,f2);                                          %Equal to codes before                      
    elseif type==2
        m = f1*(f2-f1)/(pw*f2);                                            %Page 37 of《声呐技术(第二版)》田坦编著
        sync = real(exp(-1i*(2*pi*f1*f1/m)*log(1-m*t/f1)));                %Hyperbolic FM signal
    end
    
    if nargin==5                                                           %Determine the number of input parameters.
    elseif varargin{1}==1
        f = fftshift(fft(sync));                                           %Codes following is used for plotting 'Amplitude Spectrum'.
        len = length(f);
        f_p = f(len/2+1:end);
        w = linspace(0, fs/2, length(sync)/2);    
        figure
        plot(w,abs(f_p))
        ylabel('Amplitude');xlabel('Frequency/Hz');title('Amplitude Spectrum');
    elseif varargin{1}==2
        spectrogram(sync,256,250,256,fs,'yaxis');                           %Plot time-frequency curve
    else
        fprintf('%d is incorrect input format.\n',varargin{1})
    end
end