function [output_decode,BER]= double_diff(m,channel_num,out_frac,channel,symbol_num,N,send_data) 
%函数功能：双差分相关接收机算法
% m:所选用的扩频序列
% channel_num:通道数，即channel向量的长度
% out_frac:接收的扩频信号经解调、降采样后的结果
% channel:通道编号，是一个向量
% symbol_num:符号数，即发送的原始（未经差分编码的）二进制比特数
% r:选用的扩频序列阶数
% send_data:发送的原始二进制比特，需要注意一下单极性/双极性，用于误码率统计
% output_decode：接收机输出的解码结果
% BER：误码率
send_data(send_data == 0) = -1; 
%% 选择不同通道的数据进行解码 主程序采用的是单通道
for num=1:channel_num
    channel_count=channel(num);
sig_bb = out_frac(channel_count,:);

if(1)
%% 解扩
% 将扩频信号以长度为N为度量，进行分段
% 将扩频信号与扩频序列做相关，每一次相关后的结果长度为2*N-1
%注意这里的循环次数是symbol_num+2，因为是双差分编码，所以参与解差分的符号数是symbol_num+2
for a=0:symbol_num+1
    R(1,1+(2*N-1)*a:(2*N-1)*(a+1))=corr_fun(sig_bb(1,1+N*a:N*(a+1)),m);  
end
%  figure;plot(real(R));
%  title("sss");
%% 解差分
% 将解扩（相关运算）输出的结果以长度为2*N-1为度量，进行分段
% 每一次经解差分算法输出的结果长度为2*N-1
% 注意这里的循环次数为symbol_num，即原始二进制比特（未经差分编码）的数量
for b=1:symbol_num
out(1,1+(2*N-1)*(b-1):(2*N-1)*b)=real((R(1,1+(2*N-1)*(b-1):(2*N-1)*b).*conj(R(1,1+(2*N-1)*b:(2*N-1)*(b+1)))).* ...
                                (conj(R(1,1+(2*N-1)*b:(2*N-1)*(b+1))).*R(1,1+(2*N-1)*(b+1):(2*N-1)*(b+2))));

    [~,index(b)] = max(abs( out(1,1+(2*N-1)*(b-1):(2*N-1)*b)));  %取每一段解差分结果的峰值（的绝对值）最大值处的索引
    if out(index(b)+(2*N-1)*(b-1)) > 0 %根据峰值的极性进行判决，决定码的极性
        output(b)=1;
    else
        output(b)=-1;
    end                            
                            
end
 figure;plot(out);
 fs=48e3;
 t1=0:1/fs:253/fs-1/fs;
 figure;plot(t1*1000,out(253*4+1:253*5)/max(out(253*4+1:253*5)));
  xlabel('Time/ms');
 ylabel('Amplitude');
end

 


%% 改进双差分相关
if(0)
for a=0:symbol_num
    R(1,1+(2*N-1)*a:(2*N-1)*(a+1))=corr_fun(sig_bb(1,1+N*a:N*(a+1)),sig_bb(1,1+N*(a+1):N*(a+2)));  
end
%  figure;plot(real(R));
for b=1:symbol_num
out(1,1+(2*N-1)*(b-1):(2*N-1)*b)=real((R(1,1+(2*N-1)*(b-1):(2*N-1)*b).*conj(R(1,1+(2*N-1)*b:(2*N-1)*(b+1)))));

    [~,index(b)] = max(abs( out(1,1+(2*N-1)*(b-1):(2*N-1)*b)));
    if out(index(b)+(2*N-1)*(b-1)) > 0
        output(b)=1;
    else
        output(b)=-1;
    end                            
                            
end


% figure;plot(out);
end

output_decode(num,:)= output;
% figure;plot(output_decode);

A=find(output~=send_data);
BER(num)=length(A)/length(send_data);


end

 end