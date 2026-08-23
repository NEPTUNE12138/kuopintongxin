function yout=corr_fun(input1,input2)
%函数功能：对两向量作互相关，通常用于实现拷贝相关
%该函数解决的问题在于：
%对于xcorr(input1,input2),若输入的两个向量的长度不同，则短的向量会自动在末尾补零,
%使二者长度相同，这就会导致互相关的结果会受到补零部分的污染，具体表现为：
%若length(input1)>length(input2),则输出的前length(input1)-length(input2)项为“受污染项”，应当删去，剩余部分为正常的互相关结果。
%若length(input1)<length(input2),则输出的后length(input2)-length(input1)项为“受污染项”，应当删去，剩余部分为正常的互相关结果。
%在使用本函数时，务必使length(input1)>length(input2)以达到预期效果
len1=length(input1);
len2=length(input2);

% s1=[input1 zeros(1,len2)];
% s2=[fliplr(input2) zeros(1,len1)];
% for k1=1:len1+len2
%     yout(k1)=fliplr(s2(1:k1))*s1(1:k1)';
% end
yout1=xcorr(input1,input2);
yout=yout1(abs(len1-len2)+1:end);
yout=yout./sqrt(sum(abs(input1.^2))*sum(abs(input2.^2)));
%the function has no zero-padding!!!!!!!
