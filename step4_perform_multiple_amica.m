function step4_perform_multiple_amica(subj, model_count, amica_frame_rej, platform, machine, gTD, saveFloat, no_process, run_ICA)
%step4_perform-multiple-amica perfoming multiple AMICA with different priors.
%   Run and evaluate multi-model AMICA on datasets with multiple
%   experiments concatenated together.
%   Number of models can be changes, but requres re-calcuation of AMICA
%   Post-AMICA analysis is included and should be run after the 
% (c) Seyed Yahya Shirazi, 02/2023 UCSD, INC, SCCN

%% initialize
clearvars -except subj model_count amica_frame_rej platform machine gTD saveFloat no_process run_ICA
close all; clc;
fs = string(filesep)+string(filesep);
fPath = split(string(mfilename("fullpath")),string(mfilename));
fPath = fPath(1);

if ~exist('subj','var') || isempty(subj), subj = "NDARBA839HLG"; else, subj = string(subj); end
if ~exist('model_count','var') || isempty(model_count), model_count = [1, 3, 5]; end
if ~exist('amica_frame_rej','var') || isempty(amica_frame_rej), amica_frame_rej = 0; end
if ~exist('platform','var') || isempty(platform), platform = "linux"; else, platform = string(platform); end
% if the code is being accessed from Expanse
if ~exist('machine','var') || isempty(machine), machine = "expanse"; else, machine = string(machine); end
% "gTD" : going to detail, usually only lets the function to create plots. Default is 1.
if ~exist('gTD','var') || isempty(gTD), gTD = 1; end
% method all together to re-write parameter or batch files, Default is 1.
if ~exist('saveFloat','var') || isempty(saveFloat), saveFloat = 1; end
% if the code is being accessed from Expanse
if ~exist('machine','var') || isempty(machine), machine = "sccn"; else, machine = string(machine); end
if ~exist('no_process','var') || isempty(no_process), no_process = 30; end
% if run AMICA on the shell which matlab is running on in the end
if ~exist('run_ICA','var') || isempty(run_ICA), run_ICA = 0; end

mergedSetName = "everyEEG";
if no_process ~= 0, p = gcp("nocreate"); if isempty(p), parpool("processes", no_process); end; end

%% construct necessary paths and files & adding paths
addpath(genpath(fPath))
p2l = init_paths(platform, machine, "HBN", 1, 1);  % Initialize p2l and eeglab.
p2l.EEGsets = p2l.eegRepo + subj + fs + "EEG_sets" + fs; % Where .set files are saved
p2l.ICA = p2l.eegRepo + subj + fs + "ICA" + fs; % Where you want to save your ICA files
p2l.incr0 = p2l.ICA + "incr0" + fs; % pre-process directory
p2l.mAmica = p2l.ICA + "mAmica" + fs;
if ~isfolder(p2l.mAmica), mkdir(p2l.mAmica); end

f2l.alltasks = subj + "_" + mergedSetName + ".set"; % as an Exception, path is NOT included
f2l.ICA_STRUCT = p2l.incr0 + subj + "_" + mergedSetName + "_ICA_STRUCT_rejbadchannels_diverse_incr_comps.mat";
f2l.elocs = p2l.codebase + "funcs" + fs + "GSN_HydroCel_129_AdjustedLabels.sfp";
f2l.float = subj + "_" + mergedSetName + "_sel_incr.fdt"; % as an Exception, path is NOT included

addpath(genpath(p2l.codebase))

%% load EEG
EEG = pop_loadset( 'filename', char(f2l.alltasks), 'filepath', char(p2l.EEGsets));
EEG = pop_chanedit(EEG, 'load', {char(f2l.elocs),'filetype','autodetect'});
% eeglab redraw
load(f2l.ICA_STRUCT,"ICA_STRUCT");
EEG = update_EEG(EEG, ICA_STRUCT);

%% setup files and parameters for AMICA with multiple models
if save_float
    % write the float
    disp("Writing float data file");
    floatwrite(double(EEG.data), char(p2l.mAmica + f2l.float));
    for i = model_count
        p2l.incr = p2l.mAmica + "m" + string(i) + fs;
        if ~isfolder(p2l.incr), mkdir(p2l.incr); end
        f2l.float_lin = f2l.float;
        p2l.incr = "m" + string(i) + fs; % path to save .param file
        f2l.param_lin = p2l.incr + subj + "_" + mergedSetName + "_m" + string(i) + "_linux.param";
        f2l.param_expanse = p2l.incr + subj + "_" + mergedSetName + "_m" + string(i) + "_expanse.param";

        linux_opts = ["files", f2l.float, "outdir", p2l.incr + "amicaout/"];
        expanse_opts = ["files",p2l.mAmica + f2l.float_lin,"outdir", p2l.incr + "amicaout/"];
        general_opts = ["data_dim", string(writeParam(i).nbchan),...
            "field_dim", string(EEG.pnts), "pcakeep", string(EEG.nbchan-1),...
            "numprocs", 1, "max_threads", 30, "block_size", 1024, "do_opt_block", 0,...
            "doPCA", 1, "writestep", 200, "do_history", 0, "histstep", 200,...
            ];

        write_amica_param(f2l.param_lin,[linux_opts, general_opts]);
        write_amica_param(f2l.param_expanse,[expanse_opts, general_opts]);        
        
    end
end

%% write SDSC Expanse shell
% However, amica is recompiled for expanse, and it is amica15ex. Still, I'd
% rather running 32 tasks/core for now, and using shared partition to be
% able to submit upto 4096 jobs.
if expanse == 0, return; end
% write batch files for each increment
expanse_root = "/home/sshirazi/HBN_EEG/";
for i = 1:length(ICA_INCR)
    opt = [];
    p2l.incr = p2l.ICA + "incr" + string(i) + fs; % path to save .slurm file
    f2l.SLURM = p2l.incr + subj + "_incr_" + string(i) + "_amica_expanse";
    f2l.param_stokes = expanse_root + subj + "/ICA/incr" + string(i) + "/" + ...
        subj + "_" + mergedSetName + "_incr_" + string(i) + "_expanse.param"; % this path is relative, that's why I'm not using p2l.ICA
    opt.file = f2l.SLURM; opt.jobName = "amc_" + subj + "_" + string(i);
    opt.partition = "shared"; opt.account = "csd403"; opt.maxThreads = 32; % param file max_threads + 2
    opt.email = "syshirazi@ucsd.edu"; opt.memory = opt.maxThreads*2;
    opt.walltime = "01:00:00"; opt.amica = "~/HBN_EEG/amica15ex"; opt.param = f2l.param_stokes;
    opt.incr_path = expanse_root + subj + "/ICA/incr" + string(i) + "/";
    write_AMICA_SLURM_file(opt);
end
% write a bash file to run AMICA on Expanse for the subject
fid = fopen(p2l.ICA + subj + "_expanse_batch","w");
fprintf(fid,"#!/bin/bash\n");
fprintf(fid,"for i in {%d..%d}\n",1, length(ICA_INCR));
fprintf(fid,"do\n");
slurm_path = expanse_root + subj + "/ICA/incr$i/" + subj + "_incr_${i}_amica_expanse.slurm";
fprintf(fid,"sbatch " + slurm_path + "\n");
fprintf(fid,"done\n");
fclose(fid);

function write_linux_bash(file,subj,start,stop)
fid = fopen(file,"w");
fprintf(fid,"#!/bin/bash\n");
fprintf(fid,"for i in {%d..%d}\n",start, stop);
fprintf(fid,"do\n");
fprintf(fid,'./amica15ub "%s/ICA/incr$i/%s_allsteps_incr_${i}_linux.param"\n',subj, subj);
fprintf(fid,"done\n");
fclose(fid);
% end of the function

function write_AMICA_SLURM_file(opt)
% SLURM steup
fid = fopen(opt.file + ".slurm", "w");
fprintf(fid,'#!/bin/sh\n');
fprintf(fid,"#SBATCH --job-name=" + opt.jobName + " # Job name\n");
% fprintf(fid,"#SBATCH --mail-type=ALL  # Mail events (NONE, BEGIN, END, FAIL, ALL)\n");
% fprintf(fid,"#SBATCH --mail-user=" + opt.email + "  # Where to send mail\n"); % disabled as it will create so many emails for incremental ICA :D
fprintf(fid,"#SBATCH --ntasks=" + string(opt.maxThreads) + " # Run a single task\n");
fprintf(fid,"#SBATCH --nodes=1  # Number of CPU cores per task\n"); % only run on one node due to mpi config of amica15ub
fprintf(fid,"#SBATCH --time=" + opt.walltime + " # Time limit hrs:min:sec\n");
fprintf(fid,"#SBATCH --output=" + opt.incr_path + opt.jobName + "_%%J.out # Standard output and error log\n");
fprintf(fid,'# Run your program with correct path and command line options\n');
% job commands
fprintf(fid, opt.amica + " " + opt.param);
fclose(fid);
% end of the function
