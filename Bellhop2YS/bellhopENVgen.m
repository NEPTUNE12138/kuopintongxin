function bellhopENVgen (soundspeeds, freq, outFileName, depth, dstep, range, ...
                        rstep, Nbeams, Runoption, R_OR_S, Sea_depth, Speed_seafloor)
%%%%%%%%% 作者：韩笑 hanxiao1322@hrbeu.edu.cn  %%%%%%%%%%%%%
%%%%%%%%%% 根据参数自动生成.env文件%%%%%%
%%% 输入：声速梯度soundspeeds  频率freq  输出env文件名称outFileName 声源深度depth x轴向接收范围range
%%%       出射角数目 Nbeams 运行类型 Runoption
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%% 修改：贾亦真  %%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    np = length(soundspeeds(:,1));
    outFileName = [outFileName,'.env']; %标题

    %% Assign head options
    nmedia = 1; %介质分层,Bellhop总为1
    options = 'NVW'; % 顶部参数
    sigma = 0;
    Z = Sea_depth; %  max(soundspeeds(:,1));% 深度最大值
    cs= 0;
    rho = 1.6;
    botopt ='A'; % 声学半空间
    NSD = 1; % 声源数目
    SD = depth; % 声源深度 (m)
    if(R_OR_S == 'S')
        NRD = 1; % 垂直接收数目（单个）
        RD = dstep; % 接收垂直深度 (m)
        NR = 1;%x轴向接收数目（单个）
    elseif(R_OR_S == 'R')
        NRD = round(Z / dstep)+1; % 垂直接收数目（范围）
        RD = Z; % 接收垂直深度 (m)（范围）
        NR = round(range*1000/rstep)+1; %x轴向接收数目（范围）
    end
    nmesh = 51; % Number of mesh points

    %% Open File
    fid = fopen(outFileName,'w');

    %% Write header options to fiLeS
    fprintf(fid, ['''',outFileName(1:end-4), '''	! TITLE \n']);%标题
    fprintf(fid, '%d	! FREQ (Hz)\n', freq);%频率
    fprintf(fid, '%d	! NMEDIA\n', nmedia);%介质分层
    fprintf(fid, ['''',options,'''	! OPTIONS \n']);%顶部参数
    fprintf(fid,'%d %.1f %.1f	! NMESH SIGMA (m) Z (NSSP) \n', nmesh,sigma,Z);%海表面参数

    % Write the bulk of the SSP
    for i=1:np
        fprintf(fid,'%.1f %.6f / \n',(soundspeeds(i,1)), soundspeeds(i,2));%声速梯度
    end

    % Write the tail options
    fprintf(fid, ['''',botopt,''' ']);%海底选项
    fprintf(fid, '%.1f  ! BOTOPT SIGMA (m) \n',sigma);%海底选项
    fprintf(fid, '%.1f %.1f %.2f %.1f %.1f %.1f / \n',Z,Speed_seafloor,cs,rho,0.25,0);%海底参数
    fprintf(fid, '%d	! NSD \n',NSD);% 声源数目
    fprintf(fid, '%.1f /	! SD (m) \n',SD);% 声源深度 (m)
    if Runoption=='Eg'
        fprintf(fid, '%d	! NRD \n',1);
        fprintf(fid,'%.1f /	! RD (m) \n', dstep);
        fprintf(fid, '%d	! NR \n',1);
        fprintf(fid,'%.1f /	! R (1:NR)(km) \n',range);
    else
        fprintf(fid, '%d	! NRD \n',NRD);% 垂直接收数目
        if(R_OR_S == 'R')
            fprintf(fid,'%.1f %.1f /	! RD (m) \n',0,RD);% 接收垂直深度 (m)（范围）
        elseif(R_OR_S == 'S')
            fprintf(fid,'%.1f /	! RD (m) \n',RD);% 接收垂直深度 (m)(单个)
        end
        fprintf(fid, '%d	! NR \n', NR);%x轴向接收数目
        if(R_OR_S == 'R')
            fprintf(fid,'%.1f %.1f /	! R (1:NR)(km) \n',0,range);%x轴向接收范围（范围）
        elseif(R_OR_S == 'S')
            fprintf(fid,'%.1f /	! R (1:NR)(km) \n', range);%x轴向接收范围(单个)
        end

    end
    fprintf(fid, ['''',Runoption,'''	! Run type: Ray/Coh/Inc/Sem \n']);%运行类型
    fprintf(fid, '%d	! NBEAMS IBEAM \n',Nbeams);%出射角数目
    fprintf(fid, '%.1f %.1f /   ! ALPHA1,2 (degrees) \n',-45,45);%出射角扇面
    fprintf(fid, '%.1f %.1f	%.1f    ! STEP (m), ZBOX (m), RBOX (km) \n',50,Z+10,range+1);%步长，声线深度，距离范围
    fclose(fid);
end








