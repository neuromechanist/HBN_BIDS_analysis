function step2_incr_rej(subj, mergedSetName, recompute, gTD, saveFloat, expanse, platform, machine, no_process, run_incr_ICA)
%STEP2_INCR_REJ Script to reject channels and frames
%   Runs the step-wisre rejection process descirbed in Shirazi and Huang,
%   TNSRE 2021. The output is in the ICA folder for each subject as
%   different steps.
%
% (c) Seyed Yahya Shirazi, 01/2023 UCSD, INC, SCCN

%% initialize
clearvars -except subj mergedSetName recompute gTD saveFloat expanse platform machine no_process run_incr_ICA
close all; clc;
fs = string(filesep)+string(filesep);

% mergedSetName can be string or a vector of strings.
if ~exist('mergedSetName','var') || isempty(mergedSetName), mergedSetName = "everyEEG"; end
if length(mergedSetName)>1
    warning("Multiple concatenated datasets provided, looping through each")
    for m = mergedSetName
        step2_incr_rej(subj, m, gTD, saveFloat, expanse, platform, machine, no_process, run_incr_ICA)
    end
    return;
end

if ~exist('subj','var') || isempty(subj), subj = "NDARAC853DTE"; else, subj = string(subj); end
% "gTD" : going to detail, usually only lets the function to create plots. Default is 1.
if ~exist('gTD','var') || isempty(gTD), gTD = 0; end
% recomputes the rejection increments
if ~exist('recompute','var') || isempty(recompute), recompute = 0; end
% save float, choose 0 for skipping saving float file, and actually all the cleaning
% method all together to re-write parameter or batch files, Default is 1.
if ~exist('saveFloat','var') || isempty(saveFloat), saveFloat = 0; end
% whether to run amica on expanse
if ~exist('expanse','var') || isempty(expanse), expanse = 1; end
if ~exist('platform','var') || isempty(platform), platform = "linux"; else, platform = string(platform); end
% if the code is being accessed from Expanse
if ~exist('machine','var') || isempty(machine), machine = "expanse"; else, machine = string(machine); end
if ~exist('no_process','var') || isempty(no_process), no_process = 28; end
% if run AMICA on the shell which matlab is running on in the end
if ~exist('run_incr_ICA','var') || isempty(run_incr_ICA), run_incr_ICA = 0; end

% Target k value, k= S/(N^2)
desired_k = 60;

ps = parallel.Settings; ps.Pool.AutoCreate = false; % prevent creating parpools automatcially
if no_process ~= 0, p = gcp("nocreate"); if isempty(p), parpool("processes", no_process); end; end

%% construct necessary paths and files & adding paths
p2l = init_paths(platform, machine, "HBN", 1, 1);  % Initialize p2l and eeglab.
p2l.EEGsets = p2l.eegRepo + subj + fs + "EEG_sets" + fs; % Where .set files are saved
p2l.ICA = p2l.eegRepo + subj + fs + "ICA" + fs; % Where you want to save your ICA files
p2l.incr0 = p2l.ICA + "incr0" + fs; % pre-process directory
if ~isfolder(p2l.incr0), mkdir(p2l.incr0); end
p2l.figs = p2l.incr0 + "figs" + fs; % pre-process directory
if ~isfolder(p2l.figs), mkdir(p2l.figs); end

f2l.alltasks = subj + "_" + mergedSetName + ".set"; % as an Exception, path is NOT included
f2l.icaStruct = p2l.incr0 + subj + "_" + mergedSetName + "_ICA_STRUCT_" + "incremental";
f2l.icaIncr = p2l.incr0 + subj + "_" + mergedSetName + "_ICA_INCR_" + "incremental";
f2l.param = p2l.incr0 + subj +"_"+ mergedSetName + "_"+"writeParam.mat"; % location of the rejection parameter file

%% reject bad channels
all_bad_chans =[129];
EEG = pop_loadset('filename',char(f2l.alltasks),'filepath',char(p2l.EEGsets));
if ~exist(f2l.icaStruct + "_all_inrements_rejbadchannels.mat","file") || recompute
    % now remove the channles based on different measures
    ICA_STRUCT = incremental_chan_rej(EEG,all_bad_chans,1,[],[],p2l.figs,1);
    save(f2l.icaStruct + "_all_inrements_rejbadchannels","ICA_STRUCT");
else
    load(f2l.icaStruct + "_all_inrements_rejbadchannels.mat", "ICA_STRUCT");
end
close all

%% plot spectopo
if gTD
    for i = 1:length(ICA_STRUCT)
        EEG2plot = update_EEG(EEG, ICA_STRUCT(i),1);
        EEG2plot = pop_reref(EEG2plot, [], 'keepref', 'on');
        figure("Name","Bad channels rejected, increment No. " + string(i));
        pop_spectopo(EEG2plot, 1, [0 EEG2plot.times(end)], 'EEG' ,'percent',100,'freq', [6 10 22], 'freqrange',[2 200],'electrodes','off');
        saveas(gcf,p2l.figs +  mergedSetName + "_rejbadchans_freqspectra_incr_" + string(i) + ".fig");
        saveas(gcf,p2l.figs + mergedSetName + "_rejbadchans_freqspectra_incr_" + string(i) + ".png");
        clear EEG2plot
        close
    end
end

%% frame rejection
duration = 10;
spacing = 100;
iqr_thres = [2 3 5 7 9];

if ~exist(f2l.icaIncr + "_all_inrements_rej_channels_frames.mat","file") || recompute
    for i = 1:length(ICA_STRUCT)
        n = (i-1)*length(iqr_thres);
        for j = n+1: n+length(iqr_thres)
            ICA_temp(j) = ICA_STRUCT(i);
        end
        EEG_INCR = update_EEG(EEG, ICA_STRUCT(i),1);
        EEG_INCR = pop_reref(EEG_INCR, [], 'keepref', 'on');
        ICA_temp1(n+1:n+length(iqr_thres)) = incremental_frame_rej(EEG_INCR, ...
            ICA_temp(n+1:n+length(iqr_thres)), iqr_thres, duration, spacing);
        clear EEG_INCR
    end
    ICA_INCR = ICA_temp1;
    clear ICA_temp ICA_temp1
    save(f2l.icaIncr + "_all_inrements_rej_channels_frames", "ICA_INCR")
else
    load(f2l.icaIncr + "_all_inrements_rej_channels_frames.mat", "ICA_INCR");
end

for i = 1:length(ICA_INCR)
    % create an array of rejected frames compatible w/ eeg_eegrej
    rejFrame(i).raw = ICA_INCR(i).rej_frame_idx; % temporary rejected frames
    rejFrame(i).rowStart = [1 find(diff(rejFrame(i).raw) > 2)+1];
    for j = 1:length(rejFrame(i).rowStart)-1
        rejFrame(i).final(j,:) = [rejFrame(i).raw(rejFrame(i).rowStart(j)) rejFrame(i).raw(rejFrame(i).rowStart(j+1)-1)];
    end
end

%% save float file to run ICA in shell & plot spectopo
if saveFloat
for i = 1:length(ICA_INCR)
    if ~isfolder(p2l.ICA + "incr" + string(i)), mkdir(p2l.ICA + "incr" + string(i)); end
    p2l.incr = p2l.ICA + "incr" + string(i) + fs;
%     f2l.float = p2l.incr + subj + "_" + mergedSetName + "_incr_" + string(i) + "_clean_float.fdt";
    EEG2write = update_EEG(EEG, ICA_INCR(i),1);
    EEG2write = pop_reref(EEG2write, [], 'keepref', 'on');
    EEG2write = eeg_eegrej(EEG2write,rejFrame(i).final);
    EEG2write.setname = subj + "_" + mergedSetName + "_incr_" + string(i);
    disp("Saving the dataset for incr. No " + string(i));
%     floatwrite(double(EEG2write.data), f2l.float); % This only wirte the fdt file, but we might need to use the full set file later.
    pop_saveset(EEG2write, 'filename', char(EEG2write.setname), 'filepath', char(p2l.incr), 'savemode', 'twofiles');
    writeParam(i).pnts = EEG2write.pnts;
    writeParam(i).nbchan = EEG2write.nbchan;
    if gTD
    figure("Name","Bad channels and frames rejected, increment No. " + string(i)); % spectopo plots.
    pop_spectopo(EEG2write, 1, [0 EEG2write.times(end)], 'EEG' ,'percent',100,'freq', [6 10 22], 'freqrange',[2 200],'electrodes','off');
    saveas(gcf,p2l.figs +  mergedSetName + "_rejbadchans_rejbadframes_freqspectra_incr_" + string(i) + ".fig");
    saveas(gcf,p2l.figs + mergedSetName + "_rejbadchans_rejbadframes_freqspectra_incr_" + string(i) + ".png");
    end
    clear EEG2write
    close
end
save(f2l.param,'writeParam')
end

%% save param files
if saveFloat == 0 && ~exist('writeParam','var') && exist(f2l.param,'file')
    load(f2l.param,'writeParam');
end
for i = 1:length(ICA_INCR)
    p2l.incr_lin = subj+ "/ICA/incr" + string(i) + "/"; % this path is relative, that's why I'm not using p2l.ICA
    f2l.float_lin = p2l.incr_lin + subj + "_" + mergedSetName + "_incr_" + string(i) + ".fdt";
    p2l.incr = p2l.ICA + "incr" + string(i) + fs; % path to save .param file
    f2l.param_lin = p2l.incr + subj + "_" + mergedSetName + "_incr_" + string(i) + "_linux.param";
    f2l.param_expanse = p2l.incr + subj + "_" + mergedSetName + "_incr_" + string(i) + "_expanse.param";

    linux_opts = ["files", f2l.float_lin, "outdir", p2l.incr_lin + "amicaout_" + mergedSetName + "/", "max_threads", 6];
    expanse_opts = ["files","~/HBN_EEG/" + f2l.float_lin,"outdir", ...
        "~/HBN_EEG/" + p2l.incr_lin + "amicaout_" + mergedSetName  + "/", "max_threads", 30];
    general_opts = ["data_dim", string(writeParam(i).nbchan),...
        "field_dim", string(writeParam(i).pnts), "pcakeep", string(writeParam(i).nbchan-1),...
        "numprocs", 1, "block_size", 1024, "do_opt_block", 0,...
        "doPCA", 1, "writestep", 200, "do_history", 0, "histstep", 200];

    write_amica_param(f2l.param_lin,[linux_opts, general_opts]);
    write_amica_param(f2l.param_expanse,[expanse_opts, general_opts]);
end

%% write linux shell
% ubunutu shell file. amica15ub cannot use dual cpu configuration (or I can't
% make it work ;D), so it is better to use two bash files simultaneously.
% not needed if amica is running on an HPC. Uncomment if ruunig locally.
% f2l.bash = p2l.eegRepo + subj + "_incremental_run_lin";
% write_linux_bash(f2l.bash + "_" + string(1),subj,1,length(ICA_INCR)/2)
% write_linux_bash(f2l.bash + "_" + string(2),subj,length(ICA_INCR)/2+1,length(ICA_INCR))

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
    f2l.SLURM = p2l.incr + subj + "_" + mergedSetName + "_incr_" + string(i) + "_amica_expanse";
    f2l.param_stokes = expanse_root + subj + "/ICA/incr" + string(i) + "/" + ...
        subj + "_" + mergedSetName + "_incr_" + string(i) + "_expanse.param"; % this path is relative, that's why I'm not using p2l.ICA
    opt.file = f2l.SLURM; opt.jobName = "amc_" + subj + "_" + mergedSetName + "_" + string(i);
    opt.partition = "shared"; opt.account = "csd403"; opt.maxThreads = 32; % param file max_threads + 2
    opt.email = "syshirazi@ucsd.edu"; opt.memory = floor(opt.maxThreads*2*0.97);
    opt.walltime = "01:30:00"; opt.amica = "~/HBN_EEG/amica15ex"; opt.param = f2l.param_stokes;
    opt.incr_path = expanse_root + subj + "/ICA/incr" + string(i) + "/";
    write_AMICA_SLURM_file(opt);
end
% write a bash file to run AMICA on Expanse for the subject
fid = fopen(p2l.ICA + subj + "_" + mergedSetName + "_expanse_batch","w");
fprintf(fid,"#!/bin/bash\n");
fprintf(fid,"for i in {%d..%d}\n",1, length(ICA_INCR));
fprintf(fid,"do\n");
slurm_path = expanse_root + subj + "/ICA/incr$i/" + subj+ "_" + mergedSetName + "_incr_${i}_amica_expanse.slurm";
fprintf(fid,"sbatch " + slurm_path + "\n");
fprintf(fid,"done\n");
fclose(fid);

%% run the jobs
% If the code is being developed on expanse, we can problably run all
% increments as soon as the float files, param files and shell files are
% created.
if run_incr_ICA
    system(sprintf("sh ~/HBN_EEG/%s/ICA/%s_%s_expanse_batch", subj, subj, string(mergedSetName)));
end

function write_linux_bash(file,subj,start,stop)
fid = fopen(file,"w");
fprintf(fid,"#!/bin/bash\n");
fprintf(fid,"for i in {%d..%d}\n",start, stop);
fprintf(fid,"do\n");
fprintf(fid,'./amica15ub "%s/ICA/incr$i/%s_%s_incr_${i}_linux.param"\n',subj, subj, string(mergedSetName));
fprintf(fid,"done\n");
fclose(fid);
% end of the function

function write_AMICA_SLURM_file(opt)
% SLURM steup
fid = fopen(opt.file + ".slurm", "w");
fprintf(fid,'#!/bin/sh\n');
fprintf(fid,"#SBATCH -p " + opt.partition + " # Job name\n"); % resource partition on expanse
fprintf(fid,"#SBATCH -A " + opt.account + " # Account chrged for the job\n");
fprintf(fid,"#SBATCH --job-name=" + opt.jobName + " # Job name\n");
% fprintf(fid,"#SBATCH --mail-type=ALL  # Mail events (NONE, BEGIN, END, FAIL, ALL)\n");
% fprintf(fid,"#SBATCH --mail-user=" + opt.email + "  # Where to send mail\n"); % disabled as it will create so many emails for incremental ICA :D
fprintf(fid,"#SBATCH --ntasks=" + string(opt.maxThreads) + " # Run a single task\n");
fprintf(fid,"#SBATCH --mem=" + string(opt.memory) + "G # default is 1G per task/core\n");
fprintf(fid,"#SBATCH --nodes=1  # Number of CPU cores per task\n"); % only run on one node due to mpi config of amica15ub
fprintf(fid,"#SBATCH --time=" + opt.walltime + " # Time limit hrs:min:sec\n");
fprintf(fid,"#SBATCH --output=" + opt.incr_path + opt.jobName + ".out # Standard output and error log\n");
fprintf(fid,"#SBATCH --error=" + opt.incr_path + opt.jobName + ".err # Standard output and error log\n");
fprintf(fid,'# Run your program with correct path and command line options\n');
% job commands
fprintf(fid,"module purge\n");
fprintf(fid,"module load cpu/0.17.3b  gcc/10.2.0/npcyll4 slurm  openmpi/4.1.1\n");

fprintf(fid, "#SET the number of openmp threads\n");
fprintf(fid,"export MV2_ENABLE_AFFINITY=0\n");

fprintf(fid, opt.amica + " " + opt.param);
fclose(fid);
% end of the function
