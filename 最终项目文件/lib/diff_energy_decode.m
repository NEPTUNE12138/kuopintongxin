function [output_decode,BER] = diff_energy_decode(m,channel_num,out_frac,channel,symbol_num,r,send_data) 
%函数功能：差分能量接收机算法
% m:所选用的扩频序列
% channel_num:通道数，即channel向量的长度
% out_frac:接收的扩频信号经解调、降采样后的结果
% channel:通道编号，是一个向量
% symbol_num:符号数，即发送的原始（未经差分编码的）二进制比特数
% r:选用的扩频序列阶数
% send_data:发送的原始二进制比特，需要注意一下单极性/双极性，用于误码率统计
% output_decode：接收机输出的解码结果
% BER：误码率
send_data(send_data == -1) = 0;

%% 构建长度为两个符号周期的扩频序列
m1=[m,m];
m2=[m,-m];
%m1、m2的长度均为(2^r-1)*2
%% 选择不同通道的数据进行解码 主程序采用的是单通道
for num=1:channel_num
    channel_count=channel(num);
sig_bb = out_frac(channel_count,:);

%% 解扩、解差分
%注意这里的循环次数为symbol_num
%将扩频信号以长度为(2^r-1)*2为度量，进行分段
%每一段分别与m1、m2进行相关，每次输出结果长度均为(2^r-1)*4-1，分别存入R1和R2
for a=0:symbol_num-1
     R1(1,1+((2^r-1)*4-1)*a:((2^r-1)*4-1)*(a+1))=corr_fun(sig_bb(1,1+(2^r-1)*a:(2^r-1)*(a+2)),m1);
    R2(1,1+((2^r-1)*4-1)*a:((2^r-1)*4-1)*(a+1))=corr_fun(sig_bb(1,1+(2^r-1)*a:(2^r-1)*(a+2)),m2);
    %提取每次存入R1、R2中的结果的峰值（的绝对值），进行比较，决定解码的结果
    if  max(abs(R1(1,1+((2^r-1)*4-1)*a:((2^r-1)*4-1)*(a+1))))<max(abs( R2(1,1+((2^r-1)*4-1)*a:((2^r-1)*4-1)*(a+1))))
         output(a+1)=0;
    else 
         output(a+1)=1;
    end

end

% figure;plot(abs(R1),'r');
%  hold on
%  plot(abs(R2),'b');

output_decode(num,:)= output;

A=find(output~=send_data);
BER(num)=length(A)/length(send_data);

% [num(num),rat(num)] = symerr(output,send_data);
end
% figure;plot(abs(real(R1(1,1+((2^r-1)*4-1)*5:((2^r-1)*4-1)*(5+1)))),'r','linewidth',1);
% hold on
% plot(real(abs(R2(1,1+((2^r-1)*4-1)*5:((2^r-1)*4-1)*(5+1)))),'b','linewidth',1);
% xlabel('Samples');
%  ylabel('Amplitude');

end