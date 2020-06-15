%==========================================================================
% run_FFR is used to specify the X and Y datasets for FFR performs function on function regression as described GBF stands for Generalized Basis Function. The
% user can specify a DWT only or PCA + DWT basis expansion of the predictor
% function. The outcome function is modeled using DWT. . 
%==========================================================================
           
%% User settings %%
outPath = sprintf('%s/Results/',pwd);
seedID = 1;
FDRdelta = 0.01;
rng(seedID); % set seed
addpath('C:/Users/Michele/Dropbox/Brent Coull/Michele/WFFR');
GBF = 0; % 0 if no compression on functional exposure data

% settings for covariates
useCov = 0;
pcaCov = 0;
pcaCovThreshold = 95;



%% Exposure and Covariate input: load, truncate, and join in one matrix
% read in scalar covariates and exposure data with row offset of 1 to
% ignore columns names
X = csvread('simX_N400_T90.csv'); % include offset of 1 if file has a header e.g. csvread('filename', 1)
N = size(X, 1);
T = size(X,2);

if useCov == 1
    C = csvread('Covariates.csv', 1);
    contVarCol = [1 2 5 12:18];
    catVarCol = setdiff([1:size(C,2)], contVarCol);
    contVars = C(:,contVarCol);
    catVars = C(:, catVarCol);
    % center and scale continuous scalar covariates to have mean 0, sd = 1
    colC = size(contVars,2);  % number of continuous scalar covariates
    scaleC     = zeros(N,colC);
    stdC        = zeros(1,colC); % store the std deviation of X for undoing standardization later
    for i = 1:colC
        col_i          = contVars(:,i);
        tempStd         = std(col_i);
        tempMean        = mean(col_i);
        scaleC(:,i)     = (col_i-tempMean)/tempStd;
        stdC(i)         = tempStd;
    end
    contVars = scaleC;
    fprintf('\n Done scaling continuous covariates.\n \n');

    if pcaCov == 1
       [coeff,score,latent,~,explained] = pca(contVars);
       cumExp = cumsum(explained);
       maxVarComps = find(cumExp > pcaCovThreshold, 1);
       compC = score(:, 1:maxVarComps);
       fprintf('\n Number of PCA factors kept = %d ,\n', size(compC, 2));
       C = [compC catVars]; 
       fprintf('\n Number of covariates after PCA = %d \n',size(C,2));
    end
    
    nScalarCov = size(C,2);
    X = [C X];
else
    nScalarCov = 0;
end
    
%% Methylation input: load, truncate (if desired), and transpose 
Y = csvread('simY_N400_S100.csv'); % rows contain subjects, N x S
S = size(Y,2); 

 %% Generate Z matrix %%
Z = []; % added by MZ - want isempty(Z) in flmm.m to be 1
b1      = zeros(T,S); % added MZ 4/16/18 (true surface is all zeroes), ideally get rid of this since we don't know true surface



%% set model params %%
SIMspecs.trueB      = b1;
SIMspecs.nScalarCov = nScalarCov;
FDR                 = [FDRdelta, 0.05]; % second argument is the alpha level
TSspecs.twosample   = 0; % changing this to 0
% TSspecs.group       = group;
% TSspecs.delt0       = 0.05;
% TSspecs.delt1       = 0.05;

%% PCA specs
if GBF == 0
    pcaspecsx.pca            = 0;
else 
 pcaspecsx.pca_cutoff    = [0.9, 0.95, 0.975, 0.99, 0.995, 0.999, 0.9999];
 pcaspecsx.pca_level     = 0.9999;
end
%% x(v) wavelet specs %%
wavespecsx.comp_level       = 0.99;
wavespecsx.alph             = [0.9,0.95,0.99,0.995,0.999,0.9999];
wavespecsx.xticks           = [5 10 15 20 25 30 35 40 45 50 55];
wavespecsx.nlevels          = 6;
wavespecsx.wavelet          = 'db4'; 
wavespecsx.wtmode           = 'zpd';
wavespecsx.ndim             = 1;

%% y(t) wavelet specs %%
wavespecsy.nlevels          = 6;
wavespecsy.wavelet          = 'db4';
wavespecsy.wtmode           = 'zpd';

%% MCMC specs %%
MCMCspecs.B                 = 100; %2000
MCMCspecs.burnin            = 100;     % 1000
MCMCspecs.thin              = 1;
MCMCspecs.propsdTheta       = 1;
MCMCspecs.nj_nosmooth       = 1;        % can be 0, if is 0, don't do any constraint for pi_{ij}, bigTau_{ij}.
MCMCspecs.minp              = 1e-14;
MCMCspecs.maxO              = 1e20;
MCMCspecs.minVC             = 1e-20;
MCMCspecs.VC0_thresh        = 1e-4;
MCMCspecs.delta_theta       = 1e-4;  % originally set to 1e-4
MCMCspecs.thetaMLE_maxiter  = 10^6;
MCMCspecs.EmpBayes_maxiter  = 10^6;
MCMCspecs.time_update       = 100;
MCMCspecs.tau_prior_var     = 1e3;      % the variance of tau_{ijk} when finding prior parameters for tau_{ijk}.
MCMCspecs.tau_prior_idx     = 1;        % 1 indicate that a_tau and b_tau depend on ij, 0 indicate that they depend on jk. 
MCMCspecs.PI_prior_var      = 0.06;     % this range should be in [0.02 0.09].
MCMCspecs.pi_update         = 1;        
MCMCspecs.tau_update        = 1;       

%% Run Model
tic;
results             = flmm_sim_staticCov3(Y, X, Z, FDR, SIMspecs, TSspecs, MCMCspecs, wavespecsx, wavespecsy, GBF, 0, pcaspecsx); 
results.runtime     = toc;
results.Y = Y;
results.X = X;
%% Save results object and make heatmaps
fname = sprintf('%sFFR_output', outPath);
save(fname, 'results', '-v7.3'); 
make_sim_heatmaps(results, outPath);  
