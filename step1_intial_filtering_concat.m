function step1_intial_filtering_concat(subj, platform, machine, have_gui, no_process)
%STEP1_INITIAL_FILTERING_CONCAT firstline filtering and concatenation of the datasets. 
%   This function imports EEG datasets for a specific subject. Note that
%   while this function only has one input, there are several files and
%   settings that are set or loaded to the function along the way. The best
%   way to get used to the settings of this function is to run it on a
%   samples dataset and then create similar structure for your source files
%   and folders to have the best experience for importing your files.
%   Also,for importing multiple subjects, you can use "run_eeg_in_batch.m"
%   with your datasets once you made sure that your data fits the settings
%   needed for this function.
%
% (c) Seyed Yahya Shirazi, 12/2022 UCSD, INC, SCCN

%% intialize

% clearvars -except subj machine have_gui no_process;
close all; clc;
fs = string(filesep) + string(filesep);  % file seperator, doubled to avoid char shortcuts in PCs

% locutoff  - lower edge of the frequency pass band (Hz)  {0 -> lowpass}
% hicutoff  - higher edge of the frequency pass band (Hz) {0 -> highpass}
filterParam.low = 1;
filterParam.high = 0;

if ~exist('subj','var') || isempty(subj), subj = "NDARAA948VFH"; else, subj = string(subj); end
if ~exist('platform','var') || isempty(platform), platform = "linux"; else, platform = string(platform); end
% if the code is being accessed from Expanse
if ~exist('machine','var') || isempty(machine), machine = "expanse"; else, machine = string(machine); end
if ~exist('have_gui','var') || isempty(have_gui), have_gui = true; end
if ~exist('no_process','var') || isempty(no_process), no_process = 30; end  % no of processors for parpool

mergedSetName = "everyEEG";

if no_process ~= 0, p = gcp("nocreate"); if isempty(p), parpool("processes", no_process); end; end

%% construct necessary paths and files & adding paths

p2l = init_paths(platform, machine, "HBN", 1, have_gui);  % Initialize p2l and eeglab.
p2l.rawEEG = p2l.raw + subj + fs + "EEG/raw/mat_format" + fs;  % Where your raw files are stored
p2l.rawEEG_updated = p2l.eegRepo + subj + fs + "EEG/remedied_raw/mat_format" + fs;
p2l.EEGsets = p2l.eegRepo + subj + fs + "EEG_sets" + fs;  % Where you want to save your .set files
p2l.ICA = p2l.eegRepo + subj + fs + "ICA" + fs;   % Where you want to save your ICA files
p2l.elocs = p2l.eegRepo;  % we need to use a template for now.
p2l.powerSpectPlot = p2l.EEGsets + "freq_spec_plots" + fs ;

for i = ["EEGsets", "ICA", "elocs", "powerSpectPlot", "rawEEG_updated"]
    if ~isfolder(p2l.(i)), mkdir(p2l.(i)); end
end
clear EEG
f2l.elocs = p2l.elocs + "GSN_HydroCel_129.sfp";  % f2l = file to load
addpath(genpath(p2l.codebase))

%% import EEG datasets
eeg_files = find_matfiles(p2l.rawEEG);
for f = eeg_files
    setname = split(f, ".mat");
    setname = setname(1);
    if contains(setname, "-"), setname = replace(setname, "-", "_"); end
    tempload = load(p2l.rawEEG + f);
    EEG.(setname) = tempload.EEG;
end
        
%% remedy the EEG structure
% The EEG struxture above is stripped of all non-data fields. They need to
% be remade.
for f = string(fieldnames(EEG))'
    EEG.(f).setname = char(subj + "_" + f);
    EEG.(f).subject = char(subj);
    EEG.(f) = eeg_checkset(EEG.(f));
    EEG.(f) = pop_chanedit(EEG.(f), 'load', {char(f2l.elocs),'filetype','autodetect'});
    EEG.(f) = pop_chanedit(EEG.(f), 'setref',{'1:129','Cz'});
    [EEG.(f).event.latency] = deal(EEG.(f).event.sample);
    EEG.(f) = eeg_checkset(EEG.(f), 'makeur');
    EEG.(f) = eeg_checkset(EEG.(f), 'chanlocs_homogeneous');
    % save the remedied EEG structure.
    pop_saveset(EEG.(f), 'filename', char(f), 'filepath', char(p2l.rawEEG_updated));
end

%% highpass, cleanline, and save individual datasets

for f = string(fieldnames(EEG))'
    figure("Name", string(EEG.(f).setname) + "_raw_freqspectra" );
    pop_spectopo(EEG.(f), 1, [0 EEG.(f).times(end)], 'EEG' ,'percent',100,'freq', [6 10 22], 'freqrange',[2 200],'electrodes','off');
%     saveas(gcf, p2l.powerSpectPlot + string(EEG.(f).setname) + "_raw_freqspectra.fig");
    saveas(gcf, p2l.powerSpectPlot + string(EEG.(f).setname) + "_raw_freqspectra.png");

    % low-pass filter
    EEG.(f) = pop_eegfiltnew(EEG.(f),filterParam.low,filterParam.high);
    EEG.(f).etc.filter = 'pop_eegfilt(EEG,filter_lo,filter_hi)';
    EEG.(f) = eeg_checkset(EEG.(f)); % alway checkset
    
    figure("Name",string(EEG.(f).setname) + "_filtered_freqspectra");
    pop_spectopo(EEG.(f), 1, [0 EEG.(f).times(end)], 'EEG' ,'percent',100,'freq', [6 10 22], 'freqrange',[2 200],'electrodes','off');
%     saveas(gcf, p2l.powerSpectPlot + string(EEG.(f).setname) + "_filtered_freqspectra.fig");
    saveas(gcf, p2l.powerSpectPlot + string(EEG.(f).setname) + "_filtered_freqspectra.png");

    % channel rejection
    % while we will do some rejection later on on step2, it might be good if we
    % have the very liberal cleaning for off channels here as well.
    [~,EEG.(f).etc.bad_chans_firstrun,~] = pop_rejchan(EEG.(f),'threshold',[-5 5],'elec',1:EEG.(f).nbchan-1, ...
        'norm','on','measure','spec');
    EEG.(f) = pop_interp(EEG.(f),EEG.(f).etc.bad_chans_firstrun,'spherical');
    [~,EEG.(f).etc.bad_chans_secondrun,~] = pop_rejchan(EEG.(f),'threshold',[-5 5],'elec',1:EEG.(f).nbchan-1, ...
        'norm','on','measure','spec');
    EEG.(f) = pop_interp(EEG.(f),EEG.(f).etc.bad_chans_secondrun,'spherical');    
    figure("Name",string(EEG.(f).setname) + "_chanrej_5std-wrt-spec");
    pop_spectopo(EEG.(f), 1, [0 EEG.(f).times(end)], 'EEG' ,'percent',100,'freq', [6 10 22], 'freqrange',[2 200],'electrodes','off');
%     saveas(gcf, p2l.powerSpectPlot + string(EEG.(f).setname) + "_filtered_freqspectra.fig");
    saveas(gcf, p2l.powerSpectPlot + string(EEG.(f).setname) + "_chanrej_5std-wrt-spec.png");
    
    % now cleanline
    EEG.(f) = pop_cleanline(EEG.(f), 'bandwidth',2,'chanlist',1:128,...
        'computepower',1,'linefreqs',[60 120 180] ,'normSpectrum',0,'p',0.05,'pad',2,'plotfigures',0,...
        'scanforlines',1,'sigtype','Channels','tau',100,'verb',1,'winsize',2.1992,'winstep',2.1992, 'newversion', true);
    EEG.(f) = eeg_checkset(EEG.(f)); % always checkset
%     EEG.(f).(i) = EEG.(f);
    
    figure("Name",string(EEG.(f).setname) + "_cleanline2_freqspectra");
    pop_spectopo(EEG.(f), 1, [0 EEG.(f).times(end)], 'EEG' ,'percent',100,'freq', [6 10 22], 'freqrange',[2 200],'electrodes','off');
%     saveas(gcf, p2l.powerSpectPlot + string(EEG.(f).setname) + "_cleanline2_freqspectra.fig");
    saveas(gcf, p2l.powerSpectPlot + string(EEG.(f).setname) + "_cleanline2_freqspectra.png");

    pop_saveset(EEG.(f),'filename',[EEG.(f).setname '.set'], 'filepath',char(p2l.EEGsets));

    close all
end

%% merge EEG sets

for f = string(fieldnames(EEG))'
    f2l.merge(f==string(fieldnames(EEG))') = cellstr([EEG.(f).setname '.set']);
end

mEEG = []; ALLEEG = [];
mEEG = pop_loadset('filename',f2l.merge,'filepath',char(p2l.EEGsets));
[ALLEEG, ~, ~] = pop_newset(ALLEEG, mEEG, 0,'study',0);
mEEG = pop_mergeset(ALLEEG, 1:1:length(f2l.merge), 0);
mEEG.setname = char(subj+"_"+mergedSetName);
% [ALLEEG, ~, ~] = pop_newset(ALLEEG, mEEG, length(trialTypes2merge),'gui','off');
pop_saveset(mEEG, 'filename', char(subj+"_"+mergedSetName), 'filepath', char(p2l.EEGsets), 'savemode', 'twofiles');
