function step2_incr_rej(subj, gTD, saveFloat, platform, machine, no_process)
%STEP2_INCR_REJ Script to reject channels and frames
%   Runs the step-wisre rejection process descirbed in Shirazi and Huang,
%   TNSRE 2021. The output is in the ICA folder for each subject as
%   different steps.
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
if ~exist('platform','var') || isempty(platform), platform = "linux"; else, platform = string(platform); end
if ~exist('machine','var') || isempty(machine), machine = "sccn"; else, machine = string(machine); end
if ~exist('no_process','var') || isempty(no_process), no_process = 30; end

mergedSetName = "everyEEG";
% Target k value
desired_k = 60;

if no_process ~= 0, p = gcp("nocreate"); if isempty(p), parpool("processes", no_process); end; end

%% construct necessary paths and files & adding paths

addpath(genpath(fPath))
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