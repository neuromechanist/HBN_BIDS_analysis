function step4_perform_multiple_amica(subj, gTD, saveFloat, machine, no_process)
%step4_perform-multiple-amica perfoming multiple AMICA with different priors.
%
% (c) Seyed Yahya Shirazi, 01/2023 UCSD, INC, SCCN

%% initialize
clearvars -except subj gTD saveFloat machine no_process
close all; clc;
fs = string(filesep)+string(filesep);
fPath = split(string(mfilename("fullpath")),string(mfilename));
fPath = fPath(1);

if ~exist('subj','var') || isempty(subj), subj = "NDARAA075AMK"; else, subj = string(subj); end
% "gTD" : going to detail, usually only lets the function to create plots. Default is 1.
if ~exist('gTD','var') || isempty(gTD), gTD = 1; end
% save float, choose 0 for skipping saving float file, and actually all the cleaning
% method all together to re-write parameter or batch files, Default is 1.
if ~exist('saveFloat','var') || isempty(saveFloat), saveFloat = 1; end
% if the code is being accessed from Expanse
if ~exist('machine','var') || isempty(machine), machine = "sccn"; else, machine = string(machine); end
if ~exist('no_process','var') || isempty(no_process), no_process = 30; end

mergedSetName = "everyEEG";
% Target k value
desired_k = 60;

if no_process ~= 0, p = gcp("nocreate"); if isempty(p), parpool("processes", no_process); end; end

%% construct necessary paths and files & adding paths

addpath(genpath(fPath))
p2l = init_paths("unix", machine, "HBN", 1, 1);  % Initialize p2l and eeglab.
p2l.EEGsets = p2l.eegRepo + subj + fs + "EEG_sets" + fs; % Where .set files are saved
p2l.ICA = p2l.eegRepo + subj + fs + "ICA" + fs; % Where you want to save your ICA files
p2l.incr0 = p2l.ICA + "incr0" + fs; % pre-process directory
if ~isfolder(p2l.incr0), mkdir(p2l.incr0); end
p2l.figs = p2l.incr0 + "figs" + fs; % pre-process directory
if ~isfolder(p2l.figs), mkdir(p2l.figs); end

f2l.alltasks = subj + "_" + mergedSetName + ".set"; % as an Exception, path is NOT included
f2l.icaStruct = p2l.incr0 + subj + "_" + mergedSetName + "_ICA_STRUCT_" + "incremental";
f2l.icaIncr = p2l.incr0 + subj + "_" + mergedSetName + "_ICA_INCR_" + "incremental";

%% reject bad channels
all_bad_chans =[129];
EEG = pop_loadset('filename',char(f2l.alltasks),'filepath',char(p2l.EEGsets));
if ~exist(f2l.icaStruct + "_all_inrements_rejbadchannels.mat","file")
    % now remove the channles based on different measures
    ICA_STRUCT = incremental_chan_rej(EEG,all_bad_chans,[],[],p2l.figs,1);
    save(f2l.icaStruct + "_all_inrements_rejbadchannels","ICA_STRUCT");
else
    load(f2l.icaStruct + "_all_inrements_rejbadchannels.mat","ICA_STRUCT")
end
close all

%% plot spectopo
if gTD
    for i = 1:length(ICA_STRUCT)
        EEG2plot = update_EEG(EEG, ICA_STRUCT(i));
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

if ~exist(f2l.icaIncr + "_all_inrements_rej_channels_frames.mat","file")
    for i = 1:length(ICA_STRUCT)
        n = (i-1)*length(iqr_thres);
        for j = n+1: n+length(iqr_thres)
            ICA_temp(j) = ICA_STRUCT(i);
        end
        EEG_INCR = update_EEG(EEG, ICA_STRUCT(i));
        ICA_temp1(n+1:n+length(iqr_thres)) = incremental_frame_rej(EEG_INCR, ...
            ICA_temp(n+1:n+length(iqr_thres)), iqr_thres, duration, spacing);
        clear EEG_INCR
    end
    ICA_INCR = ICA_temp1;
    clear ICA_temp ICA_temp1
    save(f2l.icaIncr + "_all_inrements_rej_channels_frames","ICA_INCR")
else
    load(f2l.icaIncr + "_all_inrements_rej_channels_frames.mat","ICA_INCR")
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
    f2l.float = p2l.incr + subj + "_" + mergedSetName + "_incr_" + string(i) + "_clean_float.fdt";
    EEG2write = update_EEG(EEG, ICA_INCR(i));
    EEG2write = eeg_eegrej(EEG2write,rejFrame(i).final);
    disp("Writing float data file for incr. No " + string(i));
    floatwrite(double(EEG2write.data), f2l.float);
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
save(p2l.incr0 + "writeParam",'writeParam')
end

%% save param files
if saveFloat == 0 && ~exist('writeParam','var') && exist(p2l.incr0 + "writeParam.mat",'file')
    load(p2l.incr0 + "writeParam",'writeParam');
end
for i = 1:length(ICA_INCR)
    p2l.incr_lin = subj+ "/ICA/incr" + string(i) + "/"; % this path is relative, that's why I'm not using p2l.ICA
    f2l.float_lin = p2l.incr_lin + subj + "_" + mergedSetName + "_incr_" + string(i) + "_clean_float.fdt";
    p2l.incr_win = subj+ "\ICA\incr" + string(i) + "\";
    f2l.float_win = p2l.incr_win + subj + "_" + mergedSetName + "_incr_" + string(i) + "_clean_float.fdt";
    p2l.incr = p2l.ICA + "incr" + string(i) + fs; % path to save .param file
    f2l.param_lin = p2l.incr + subj + "_" + mergedSetName + "_incr_" + string(i) + "_linux.param";
    f2l.param_win = p2l.incr + subj + "_" + mergedSetName + "_incr_" + string(i) + "_windows.param";
    f2l.param_stokes = p2l.incr + subj + "_" + mergedSetName + "_incr_" + string(i) + "_stokes.param";

    linux_opts = ["files", f2l.float_lin, "outdir", p2l.incr_lin + "amicaout/"];
    stokes_opts = ["files","~/EEG/" + f2l.float_lin,"outdir", "~/EEG/" + p2l.incr_lin + "amicaout/"];
    windows_opts = ["files", f2l.float_win, "outdir", p2l.incr_win + "amicaout\"];
    general_opts = ["data_dim", string(writeParam(i).nbchan),...
        "field_dim", string(writeParam(i).pnts), "pcakeep", string(writeParam(i).nbchan),...
        "numprocs", 1, "max_threads", 10, "block_size", 1024, "do_opt_block", 0,...
        "doPCA", 0, "writestep", 200, "do_history", 0, "histstep", 200];

    write_amica_param(f2l.param_lin,[linux_opts, general_opts]);
    write_amica_param(f2l.param_win,[windows_opts, general_opts]);
    write_amica_param(f2l.param_stokes,[stokes_opts, general_opts]);
end

%% write bash (or batch) file for to run AMICA from command line
% ubunutu bash file. amica15ub cannot use dual cpu configuration (or I can't
% make it work ;D), so it is better to use two bash files simultaneously. 
f2l.bash = p2l.eegRepo + subj + "_incremental_run_lin";
write_linux_bash(f2l.bash + "_" + string(1),subj,1,length(ICA_INCR)/2)
write_linux_bash(f2l.bash + "_" + string(2),subj,length(ICA_INCR)/2+1,length(ICA_INCR))

% windows batch file
% f2l.batch = p2l.eegRepo + subj + "_incremental_run_win";
% write_windows_batch(f2l.batch + "_" + string(1),subj,1,length(ICA_INCR)/2)
% write_windows_batch(f2l.batch + "_" + string(2),subj,length(ICA_INCR)/2+1,length(ICA_INCR))

%% wirte bash files to run on SDSC Expanse
if expanse == 0, return; end
% write batch files for each increment
stokes_root = "EEG/";
for i = 1:length(ICA_INCR)
    opt = [];
    p2l.incr = p2l.ICA + "incr" + string(i) + fs; % path to save .slurm file
    f2l.SLURM = p2l.incr + subj + "_incr_" + string(i) + "_amica_STOKES";
    f2l.param_stokes = stokes_root + subj + "/ICA/incr" + string(i) + "/" + ...
        subj + "_" + mergedSetName + "_incr_" + string(i) + "_stokes.param"; % this path is relative, that's why I'm not using p2l.ICA
    opt.file = f2l.SLURM; opt.jobName = "amica" + subj + "_" + string(i);
    opt.email = "seyed@knights.ucf.edu"; opt.maxThreads = 12; % param file max_threads + 2
    opt.walltime = "01:00:00"; opt.amica = "~/EEG/amica15ub"; opt.param = f2l.param_stokes;
    opt.incr_path = stokes_root + subj + "/ICA/incr" + string(i) + "/";
    write_AMICA_SLURM_file(opt);
end
% write a bash file to run AMICA on Stokes for the subject
fid = fopen(p2l.ICA + subj + "_STOKES_batch","w");
fprintf(fid,"#!/bin/bash\n");
fprintf(fid,"for i in {%d..%d}\n",1, length(ICA_INCR));
fprintf(fid,"do\n");
slurm_path = stokes_root + subj + "/ICA/incr$i/" + subj + "_incr_${i}_amica_STOKES.slurm";
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
