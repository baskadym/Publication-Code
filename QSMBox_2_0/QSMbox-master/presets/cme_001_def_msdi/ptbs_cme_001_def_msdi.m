function ptbs_cme_001_def_msdi(flag)
% QSMbox
%  Default MSDI v1 pipeline for coil-combined multi-GRE data
%
% USAGE 
%  + Edit CUSTOM SETTINGS (below) if necessary 
%  + Save & Run (F5)
% 
% REQUIREMENTS
%  + Select readout type, i.e. monopolar or bipolar
%  + If 'ptb.roi.bet2.run' enabled, FSL installation required
% 
% DEFAULTS 
%  + Program will autoload the following files if in pwd:
%    - magn_orig.nii(.gz)              magnitude data           4D, [3D_vols,echo]
%    - phase_orig.nii(.gz)             phase data               "Idem"
% 
%  + If 'ptb.roi.custom.run' enabled the following file (in pwd) will skip manual input:
%    - roi.nii(.gz)                    ROI mask
%  
%  + Scan parameter input could also be automated if the following files were available in pwd:
%    - ptb_scaling_factor.txt          phase scaling,           e.g. 4096 (Siemens convention)
%    - ptb_res.txt                     voxel size in mm,        e.g. 1 1 1 
%    - ptb_TE.txt                      echo times in s,         e.g. 2.34e-3 4.64e-3 6.94e-3 9.24e-3 11.54e-3 13.84e-3 16.14e-3 18.44e-3
%    - ptb_B0.txt                      field strength in T,     e.g. 3
%    - ptb_B0_dir.txt                  main field direction,    e.g. 0 0 1 (slices perp to B0), or 0 0.5 0.866 (30deg rot)
%    NOTE: The above -except scaling factor & TEs- can be autoextracted from a single DICOM file in a 'dicom' (small caps) dir (in pwd)
% 
%  + Dir structure example:
%     working_dir/magn_orig.nii(.gz)
%                /phase_orig.nii(.gz)
%                /ptb_scaling_factor.txt
%                /ptb_TE.txt
%                /dicom/sample_dicom.dcm
%
%  + If any (or all) of the above missing you will be prompted for manual input
% 
% PIPELINE STEPS
%  1. prep.all  -------------------------  Preparation steps (see below)
%     - prep.load_default ---------------   Load 3D/4D magnitude & phase sets into magn[phase]_orig MATLAB variables. If magn[phase]_orig.nii* in pwd, they will be loaded automagically
%     - prep.import_params  -------------   Import voxel size, echo time(s), field strength, field direction and phase scaling factor 
%     - prep.rescaling  -----------------   Rescale wrapped phases to the range: [-pi,pi] rads
%     - prep.magn_comb  -----------------   Combine magnitude image as the root-sum-of-squares along magn_orig's 4th dimension
%     - prep.roi  -----------------------   Estimate/load ROI mask. See CUSTOM SETTINGS below
%  2. prep.init_offset_corr -------------  Transmit-phase offset correction and (optional) odd/even echo adjustment for bipolar readouts (based on public-domain code from Hongfu Sun)
%  3. prep.unwr4d.srncp  ----------------  Echo-wise best-path unwrapping with second difference (phase reliability) calculation and 2*pi jump temporal correction (based on code from Abdul-Rahman et al. Applied Optics 2007 available from HF Sun's GitHub repo)
%  4. comb.echofit  ---------------------  Phase estimation via WLS phase fitting (adapted from HF Sun implementation)
%  5. bfe.lbv  --------------------------  Full-multigrid Laplacian boundary value filtering (available from MEDI toolbox)
%  6. bfe.vsmv  -------------------------  Variable spherical mean value filtering (Bilgic/Bouwman implementation)
%  7. qsm.MSDI  -------------------------  Multi-scale dipole inversion (MSDI) for QSM (see Acosta-Cabronero et al. Neuroimage 2018)
% 
% Created by Julio Acosta-Cabronero

if nargin<1
    flag = 'run';
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Uncomment below if you wish the present settings file to appear in the 
% list of PRESET OPTIONS.
%
% flag = 'preset';
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% CUSTOM SETTINGS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% DEFINE PIPELINE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
disp('Default MSDI v1 pipeline for combined multi-echo data')
ptb.pipename = {'cme_001_def_msdi'};
ptb.pipeline = {'prep.all'...
                'prep.init_offset_corr',...
                'prep.unwr4d.srncp',...
                'comb.echofit',...
                'bfe.lbv',...
                'bfe.vsmv',...
                'qsm.MSDI'};

%% PREP OPTIONS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Zero-padding
ptb.iso_reslice = true;
                % if [true], and slice thickness > 1.1*mean_inplane_vx_size,
                %  reslice (via zeropadding) to isotropic vx resolution

%% ROI MASK ESTIMATION %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Custom ROI mask
ptb.roi.custom.run = false;    
                   % [true] custom ROI mask (roi.nii/.gz in pwd) will be autoloaded 
                   % NOTE: if [true], but roi.nii/.gz not in pwd, it will prompt for manual input

% SPM, https://www.fil.ion.ucl.ac.uk/spm
ptb.roi.spm.run       = true;
ptb.roi.spm.settings  = '3T_default';
                      % alternative preset: '7T_default';
ptb.roi.spm.thr       = 1e-4;    
                      % c1+c2+c3 probability cut-off threshold
ptb.roi.spm.dilR      = -1;    
                      % ROI dilation (spherical) kernel radius in mm 
                      %  [0]  no dilation
                      %  [-1] dilation by one voxel
                                            
% BET2, FSL's brain extraction tool (UNIX only)
ptb.roi.bet2.run = false;
ptb.roi.bet2.f   = 0.1;
                 % fractional threshold

%% PHASE CORRECTION %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% prep.init_offset_corr
ptb.readout = 'bipolar';
            % Multi-echo readout type
            % ['monopolar']
            % ['bipolar']

% comb.echofit 
ptb.comb.echofit.intercept = 0; 
                           % zero/non-zero fitting intercept
                           % [0] if e.g. prep.init_offset_corr enabled
                           % [1] corrects for transmit/CF mismatch
            
%% BACKGROUND FIELD EXTRACTION %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% LBV filtering
ptb.bfe.lbv.tol    = 0.001;
ptb.bfe.lbv.peel   = 0; 
ptb.bfe.lbv.depth  = -1; 
ptb.bfe.lbv.N1     = 30; 
ptb.bfe.lbv.N2     = 100; 
ptb.bfe.lbv.N3     = 100;

% vSMV filtering
ptb.bfe.vsmv.R0 = 40;   
                % initial SMV kernel radius in mm

%% QSM INVERSION %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% L1-regularised multi-scale inversion
ptb.qsm.MSDI.lambda        = 400;
                                  % Lagrange multiplier
ptb.qsm.MSDI.reliab        = 1;
                                  % Scale-wise consistency masking of unreliable phases
ptb.qsm.MSDI.reliab_excl1  = true;
                                  % Do not apply masking for scale #1   [if reliab==1]
ptb.qsm.MSDI.reliab_pct    = 10;
                                  % Init extent, percentage masking     [if reliab==1]
ptb.qsm.MSDI.merit         = 1;        
                                  % Dynamic model error reduction
ptb.qsm.MSDI.merit_f       = 6;        
                                  % MERIT's threshold
ptb.qsm.MSDI.merit_p       = 2;        
                                  % MERIT's noise model corrective power
ptb.qsm.MSDI.smv                = true;
ptb.qsm.MSDI.smv_N_std_update   = true;
                                  % If enabled, noise model will be adjusted as a function of R_smv
ptb.qsm.MSDI.R_smv              = [2,4,8,16];        
                                  % SMV kernel radii (in mm) defining each scale
                                  %  R_smv could be a vector (i.e. multi-scale QSM), 
                                  %  or a single scalar (i.e. MEDIN with SMV deconvolution)
ptb.qsm.MSDI.e                          = 1e-6;
                                               % L1-smoothing parameter
ptb.qsm.MSDI.cg_max_iter                = 2000;
                                               % Max iter # for internal conjugate gradient loop
ptb.qsm.MSDI.cg_tol                     = 0.1;
                                               % Stopping tolerance for CG loop
ptb.qsm.MSDI.max_iter                   = 25;
                                               % Max iter # for outer quasi-Newton loop
ptb.qsm.MSDI.tol_norm_ratio             = 0.1;
                                               % Stopping tolerance for outer qN loop
                                               % N.B. If R_smv(n)>6 & tol_norm_ratio<0.1, it will be reset to 0.1
ptb.qsm.MSDI.data_weighting_mode        = 1;
                                               % Magnitude weighting (consistency)
ptb.qsm.MSDI.gradient_weighting_mode    = 3;
                                               % Edge masking (regulariser)
                                               %  [1] apply to all scales
                                               %  [2] apply to all scales - if reliab==1, prioritise consistency masking
                                               %                             i.e. M_edge=1, if M_reliab==0
                                               %  [3] apply to scale #1 only
ptb.qsm.MSDI.dynedge_mode               = 0;
                                               % Edge masking type
                                               %  [0] Static I:     magnitude (all scales)
                                               %  [1] Dynamic I:    magnitude (scale #1) + QSM (subsequently)
                                               %  [2] Dynamic II:   scale-dependent SMV filtered field map [if smv]
                                               %  [3] Static II:    input field map, i.e. nfm_0 (all scales)

%% SAVE SETTINGS
flag = m1_save_ptb(ptb,flag);

%% RUN PIPELINE
ptbm_001(flag)
