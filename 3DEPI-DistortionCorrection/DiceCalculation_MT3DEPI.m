%% Dice Coeficient (DC) calculation of in both MT-3DEPI and MP2RAGE spaces 
% Calculated for MT-3DEPI data
% No-correction, B0 field mapping and reversed-PE (fsl_topup) techniques
% Native=0==>MP2RAGE space &  Native=0==>MT-3DEPI space  
% V Malekian, FIL Physics     

clc;clear;close all;
addpath('/export/home/vmalekian/MI_Distortion/NIfTI_20140122/')

SUBJT=1:22;
p=0;
thresh=0.8;
Native =1; %% Calculate DC in MT-3DEPI space % Native =0; %% Calculate DC in MP2RAGE space

for sub= SUBJT(~ismember(SUBJT,[4,7])) %% subjects 4 and 7 were excluded due to extensive motion
    
    p=p+1;
    
    if (Native==0) %% MP2RAGE space
        
        dir_seg_str= ['/export/home/vmalekian/MT_Alice_dataset_20_revision/' sprintf('%02d',sub) '/MP2RAGE_WBIC_0pt65_PAT3_PF68_240Hz_UNI/'];
        string1 = 'c1clean_uni_reo.nii';
        
        a0m=dir([dir_seg_str,string1]);
        nf=load_untouch_nii([dir_seg_str,a0m(1).name]);
        gray = im2double(nf.img);
        
        dir_reg_nc= ['/export/home/vmalekian/MT_Alice_dataset_20_revision/' sprintf('%02d',sub) '/fMRI0003/AP_noc_3/'];
        dir_reg_bp= ['/export/home/vmalekian/MT_Alice_dataset_20_revision/' sprintf('%02d',sub) '/fMRI0003/AP_top_3/'];
        dir_reg_b0= ['/export/home/vmalekian/MT_Alice_dataset_20_revision/' sprintf('%02d',sub) '/fMRI0003/AP_FM_3/'];
        
        string1 = 'c1initial_highres2highres.nii';
        a0m=dir([dir_reg_nc,string1]);
        nf=load_untouch_nii([dir_reg_nc,a0m(1).name]);
        c1_0 = im2double((nf.img));
        
        string1 = 'c1initial_highres2highres_jac.nii';
        a0m=dir([dir_reg_bp,string1]);
        nf=load_untouch_nii([dir_reg_bp,a0m(1).name]);
        c1_1 = im2double((nf.img));
        
        string1 = 'c1initial_highres2highres.nii';
        a0m=dir([dir_reg_b0,string1]);
        nf=load_untouch_nii([dir_reg_b0,a0m(1).name]);
        c1_2 = im2double((nf.img));
        
    else %% MT-3DEPI space
        
        dir_seg_str=  ['/export/home/vmalekian/MT_Alice_dataset_20_revision/' sprintf('%02d',sub) '/nc_epi3d_v2d_MTw_WholeBrain_0005/'];
        string1 = 'c1AP.nii';
        a0m=dir([dir_seg_str,string1]);
        nf=load_untouch_nii([dir_seg_str,a0m(1).name]);
        gray = im2double(nf.img);
        
        dir_reg_nc= ['/export/home/vmalekian/MT_Alice_dataset_20_revision/' sprintf('%02d',sub) '/fMRI0003/AP_noc_3/'];
        dir_reg_bp= ['/export/home/vmalekian/MT_Alice_dataset_20_revision/' sprintf('%02d',sub) '/fMRI0003/AP_top_3/'];
        dir_reg_b0= ['/export/home/vmalekian/MT_Alice_dataset_20_revision/' sprintf('%02d',sub) '/fMRI0003/AP_FM_3/'];
        
        string1 = 'c1brain2EPI.nii.gz';
        a0m=dir([dir_reg_nc,string1]);
        nf=load_untouch_nii([dir_reg_nc,a0m(1).name]);
        c1_0 = im2double((nf.img));
        
        string1 = 'c1brain2EPI.nii.gz';
        a0m=dir([dir_reg_bp,string1]);
        nf=load_untouch_nii([dir_reg_bp,a0m(1).name]);
        c1_1 = im2double((nf.img));
        
        string1 = 'c1brain2EPI.nii.gz';
        a0m=dir([dir_reg_b0,string1]);
        nf=load_untouch_nii([dir_reg_b0,a0m(1).name]);
        c1_2 = im2double((nf.img));
        
    end

    %%DC calculation
    for k1=1:41
        thresh=0.49 +(k1)/100;
        thresh_x(k1)=thresh;
        gray_masked=gray;
        c0_masked = c1_0;
        c1_masked = c1_1;
        c2_masked = c1_2;
        
        
        gray_bin = imbinarize(gray_masked,thresh);
        
        c0_bin = imbinarize(c0_masked,thresh);
        c1_bin = imbinarize(c1_masked,thresh);
        c2_bin = imbinarize(c2_masked,thresh);
        
        
        R1(p,k1) = dice(c0_bin,gray_bin);
        R2(p,k1) = dice(c1_bin,gray_bin);
        R3(p,k1) = dice(c2_bin,gray_bin);

    end
end

x= thresh_x;
sub_bp_dc = round(mean(R2,2),3);
sub_b0_dc = round(mean(R3,2),3);


figure,
[aline(1), aFill(1)] = stdshade(R1,0.15,'r',x);hold on,
[aline(2), aFill(2)] = stdshade(R3,0.15,'b',x);
[aline(3), aFill(3)] = stdshade(R2,0.15,'g',x);
aline(2).LineStyle='--';
aline(3).LineStyle='-.';
legend(aline,'No Correction','B0 field mapping','Reversed-PE')
% legend(aline,'No Corection','reversed-PE-JAC','reversed-PE-SLR')

xlabel('GM Probability Threshold'),ylabel('DC')
title('DC in MT-3DEPI space')
% title('DC in MP2RAGE space')

ylim([0.65 0.90]), grid on
set(gca,'FontSize',16),set(gcf,'Color',[1 1 1])


temp1= mean(R1,2);
temp2= mean(R2,2);
temp3= mean(R3,2);
mean_R1 = round(mean(temp1),3);
std_R1 = round(std(temp1),3);

mean_R2 = round(mean(temp2),3);
std_R2 = round(std(temp2),3);

mean_R3 = round(mean(temp3),3);
std_R3 = round(std(temp3),3);


