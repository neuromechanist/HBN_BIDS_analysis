function step4_perform_multiple_amica(subj, model_count, amica_frame_rej, platform, machine, saveFloat, run_ICA, num_prior)
%step4_perform-multiple-amica perfoming multiple AMICA with different priors.
%   Run and evaluate multi-model AMICA on datasets with multiple
%   experiments concatenated together.
%   Number of models can be changes, but requres re-calcuation of AMICA
%   Post-AMICA analysis is included and should be run after the 
% (c) Seyed Yahya Shirazi, 02/2023 UCSD, INC, SCCN

%% initialize
clearvars -except subj model_count amica_frame_rej platform machine saveFloat run_ICA
close all; clc;
fs = string(filesep)+string(filesep);
fPath = split(string(mfilename("fullpath")),string(mfilename));
fPath = fPath(1);

if ~exist('subj','var') || isempty(subj), subj = "NDARBA839HLG"; else, subj = string(subj); end
if ~exist('model_count','var') || isempty(model_count), model_count = [2, 3, 6, 9]; end
if ~exist('amica_frame_rej','var') || isempty(amica_frame_rej), amica_frame_rej = 0; end
if ~exist('platform','var') || isempty(platform), platform = "linux"; else, platform = string(platform); end
% if the code is being accessed from Expanse
if ~exist('machine','var') || isempty(machine), machine = "expanse"; else, machine = string(machine); end
% method all together to re-write parameter or batch files, Default is 1.
if ~exist('saveFloat','var') || isempty(saveFloat), saveFloat = 1; end
% if run AMICA on the shell which matlab is running on in the end
if ~exist('run_ICA','var') || isempty(run_ICA), run_ICA = 0; end
% number of priors
if ~exist('num_prior','var') || isempty(num_prior), num_prior = string(3); else, num_prior = string(num_prior); end

mergedSetName = "everyEEG";
cores = "mNode"; nodes = "4";  % Amica multi-node run
block_size = "128";  % Observing Amica1.7, block size should be very low. 
process_params = cores + "_n" + nodes + "_b"+ block_size;

partition = "compute";  % removed shared partition, observing Amica1.7
%% construct necessary paths and files & adding paths
addpath(genpath(fPath))
p2l = init_paths(platform, machine, "HBN", 1, 1);  % Initialize p2l and eeglab.
p2l.ICA = p2l.eegRepo + subj + fs + "ICA" + fs; % Where you want to save your ICA files
p2l.incr0 = p2l.ICA + "incr0" + fs; % pre-process directory
p2l.mAmica = p2l.ICA + "mAmica_" + num_prior +"p_" + process_params + fs;
if ~isfolder(p2l.mAmica), mkdir(p2l.mAmica); end

f2l.ICA_STRUCT = p2l.incr0 + subj + "_" + mergedSetName + "_ICA_STRUCT_rejbadchannels_diverse_incr_comps.mat";
f2l.float = subj + "_" + mergedSetName + "_sel_incr.fdt"; % as an Exception, path is NOT included

%% load EEG
% The best dataset should be used. Also, there is no need to resave the
% float file
ICA_STRUCT = load(f2l.ICA_STRUCT);
set_to_load = string(ICA_STRUCT.most_brain_increments.selected_incr);
if str2double(set_to_load) < 10, pathnum_to_load = "0" + set_to_load;
else, pathnum_to_load = string(set_to_load);
end
EEG_path = p2l.ICA+ "/incr" + pathnum_to_load + "/";
EEG_file = subj + "_everyEEG_incr_" + set_to_load + ".set";

EEG = pop_loadset( 'filename', char(EEG_file), 'filepath', char(EEG_path));
% eeglab redraw
EEG = update_EEG(EEG, ICA_STRUCT,1);

%% setup files and parameters for AMICA with multiple models
if saveFloat
    disp("Writing float data file");
    floatwrite(double(EEG.data), char(p2l.mAmica + f2l.float));
    for i = model_count
        p2l.incr = p2l.mAmica + "m" + string(i) + fs;
        if ~isfolder(p2l.incr), mkdir(p2l.incr); end
        f2l.float_lin = f2l.float;
        f2l.param_lin = p2l.incr + subj + "_" + mergedSetName + "_m" + string(i) + "_linux.param";
        f2l.param_expanse = p2l.incr + subj + "_" + mergedSetName + "_m" + string(i) + "_expanse.param";

        linux_opts = ["files", f2l.float, "outdir", p2l.incr + "amicaout/"];
        expanse_opts = ["files",p2l.mAmica + f2l.float_lin,"outdir", p2l.incr + "amicaout/"];
        general_opts = ["data_dim", string(EEG.nbchan),...
            "field_dim", string(EEG.pnts), "pcakeep", string(EEG.nbchan-1),...
            "numprocs", nodes, "max_threads", 4, "block_size", str2num(block_size), "do_opt_block", 0,...
            "doPCA", 1, "writestep", 1000, "do_history", 0, "histstep", 1000,...
            "num_models", i, "num_mix_comps", str2num(num_prior),"lrate", 0.01,...
            "do_reject", amica_frame_rej, "numrej", 5, "rejstart", 1, "rejint", 3, "rejsig", 3.01,...
            "min_grad_norm", "1.00000e-08", "min_dll", "1.00000e-08", "max_iter", 2500];

        write_amica_param(f2l.param_lin,[linux_opts, general_opts]);
        write_amica_param(f2l.param_expanse,[expanse_opts, general_opts]);        
        
    end
end

%% write SDSC Expanse shell
% However, amica is recompiled for expanse, and it is amica15ex. Still, I'd
% rather running 64 tasks/core for now, and using shared partition to be
% able to submit upto 4096 jobs.
% write batch files for each increment
for i = model_count
    opt = [];
    p2l.incr = p2l.mAmica + "m" + string(i) + fs; % path to save .slurm file
    if ~exist(p2l.incr,'dir'), mkdir(p2l.incr); end
    f2l.SLURM = p2l.incr + subj + "_m" + string(i) + "_amica_expanse";
    f2l.param_stokes = p2l.incr + subj + "_" + mergedSetName + "_m" + string(i) + "_expanse.param";
    opt.file = f2l.SLURM; opt.jobName = "mamc_" + subj + "_" + string(i);
    opt.partition = partition; opt.account = "csd403"; opt.nodes = nodes;
    opt.email = "syshirazi@ucsd.edu";
    opt.walltime = "04:00:00"; opt.amica = "~/HBN_EEG/amica17nsg"; opt.param = f2l.param_stokes;
    opt.incr_path = p2l.incr; opt.outdir = opt.incr_path + "amicaout/";
    write_AMICA_SLURM_file(opt);
end
% write a bash file to run AMICA on Expanse for the subject
fid = fopen(p2l.mAmica + subj + "_expanse_batch","w");
fprintf(fid,"#!/bin/bash\n");
fprintf(fid,"for i in " + string(num2str(model_count))+" \n");
fprintf(fid,"do\n");
slurm_path = p2l.mAmica + "/m$i/" + subj + "_m${i}_amica_expanse.slurm";
fprintf(fid,"sbatch " + slurm_path + "\n");
fprintf(fid,"done\n");
fclose(fid);
system(sprintf("chmod 775 ~/HBN_EEG/%s/ICA/mAmica_%sp_%s/%s_expanse_batch", subj, num_prior, process_params, subj));


%% run the jobs
% If the code is being developed on expanse, we can problably run all
% increments as soon as the float files, param files and shell files are
% created.
if run_ICA
    system(sprintf("sh ~/HBN_EEG/%s/ICA/mAmica_%sp_%s/%s_expanse_batch", subj, num_prior, process_params, subj));
end

function write_AMICA_SLURM_file(opt)
% SLURM steup
fid = fopen(opt.file + ".slurm", "w");
fprintf(fid,'#!/bin/sh\n');
fprintf(fid,"#SBATCH -p " + opt.partition + " # Job name\n"); % resource partition on expanse
fprintf(fid,"#SBATCH -A " + opt.account + " # Account chrged for the job\n");
fprintf(fid,"#SBATCH --job-name=" + opt.jobName + " # Job name\n");
% fprintf(fid,"#SBATCH --mail-type=ALL  # Mail events (NONE, BEGIN, END, FAIL, ALL)\n");
% fprintf(fid,"#SBATCH --mail-user=" + opt.email + "  # Where to send mail\n"); % disabled as it will create so many emails for incremental ICA :D
fprintf(fid,"#SBATCH --nodes=" + opt.nodes + "\n");
fprintf(fid,"#SBATCH --ntasks-per-node=32\n");
fprintf(fid,"#SBATCH --cpus-per-task=4\n");
fprintf(fid,"#SBATCH --mem=249208M\n");
fprintf(fid,"#SBATCH --time=" + opt.walltime + " # Time limit hrs:min:sec\n");
fprintf(fid,"#SBATCH --output=" + opt.incr_path + opt.jobName + ".out # Standard output and error log\n");
fprintf(fid,"#SBATCH --error=" + opt.incr_path + opt.jobName + ".err # Standard output and error log\n");
fprintf(fid,"# Run your program with correct path and command line options\n");
% job commands
fprintf(fid,"module load cpu/0.15.4 slurm intel intel-mkl mvapich2\n");
fprintf(fid,['export OMP_NUM_THREADS=' int2str(4) ...
    '; export MV2_ENABLE_AFFINITY=0; export SRUN_CPUS_PER_TASK=${SLURM_CPUS_PER_TASK}\n']);

fprintf(fid," srun --export=ALL --mpi=pmi2 " + opt.amica + " " + opt.param + "\n"); % " " + opt.outdir +
fclose(fid);
% end of the function
