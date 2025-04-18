function [ICA_STRUCT, EEG_out] = pick_diverse_ICA(p2l, f2l, subj, mergedSetName, load_existing)
% runs DIPFIT on incremental amica and standard MNI model and finds the
% increment that has the most diverse dipoles with rv < 0.15 inside the
% brain. Examining "run_dipfit_study_incremental_amica" on stepping
% database, I found that cleaning methods are really of importance. If the
% cleaning criteria is not examined and reported, there is a high chance to
% ignore the possible sources that are contributing to the task.
%
%
% REV:
%       v0 @ 6/24/2019 inception (from run_dipfit_study_incremental_amica)
%
% Created by: Seyed Yahya Shirazi, BRaIN Lab, UCF
% email: shirazi@ieee.org
%
% Copyright 2019 Seyed Yahya Shirazi, UCF, Orlando, FL 32826

%% initialize
fs = string(filesep);
rv = 15; % it should be in percentage to be compatible w/ eeg_dipselect
if ~exist("p2l","var") || isempty(p2l.ICA), error("ICA path is mandatory"); end
if ~exist('subj','var') || isempty(subj), subj = "test"; else, subj = string(subj); end
if ~exist('mergedSetName','var') || isempty(mergedSetName), mergedSetName = "everyEEG"; else, mergedSetName = string(mergedSetName); end
if ~exist('load_existing','var') || isempty(load_existing), load_existing = 1; end

p2l.incr0 = p2l.ICA + "incr0" + fs;
f2l.classify = p2l.incr0 + subj + "_" + mergedSetName + "_ICA_INCR_dipfit_classification.mat";

%% need ICA_INCR to update incremental ICA_STRUCTs

load(f2l.INCR_chan_frames, "ICA_INCR");
% let's find channles that are present in every ICA
bad_chan = [];
for i = 1:128
    for j = 1:length(ICA_INCR)
       if ~ismember(i,ICA_INCR(j).good_chans)
           bad_chan(end+1) = i; %#ok<*AGROW>
           break
       end
    end    
end

%% update folder names
% Running AMICA using "incr1" folder names is much easier than using
% "incr01", but reading the folder names in here using "dir" command,
% "incr11" will come before "incr02" changing the order. So, I think the
% easiest hack is just to change the folder names for the increment 1-9 to
% 01-09 :D
foldContent = dir(p2l.ICA);
foldName = string({foldContent(:).name});

for i = foldName
    if contains(i, "incr")
    incrString = split(i, "incr"); incrNum = str2double(incrString(2));
    if incrNum > 0 && incrNum < 10
        if contains(string(incrString(2)),"0"), break; end % means that this problem was already taken care of
        movefile([foldContent(i==foldName).folder filesep foldContent(i==foldName).name],...
            [foldContent(i==foldName).folder filesep 'incr0' int2str(incrNum)]);
    end
    end
end

%% update ICA_STRUCTs (or here ICA_INCRs)
% a question, can we load all ICA datasets together?
foldContent = dir(p2l.ICA);
foldName = string({foldContent(:).name});
if isempty(find(contains(foldName,"incr"),1))
    error("ICA path does not contain incremental folders.")
end

for i = foldName
    if foldContent(i == foldName).isdir == 1
        if contains(i, "incr")
            incrNum = split(i, "incr"); incrNum = str2double(incrNum(2));
            if incrNum > 0
                modout = loadmodout10(char(p2l.ICA + i + fs + "amicaout_" + mergedSetName));
                disp("imported ICA parpmeter for incr. " + string(incrNum));
                ICA_INCR(incrNum).weights = modout.W;
                ICA_INCR(incrNum).sphere = modout.S;
                EEG = pop_loadset( 'filename', char(subj + "_" + mergedSetName + "_incr_" + incrNum + ".set"),...
                    'filepath', char(p2l.ICA + string(i) + fs));
%                 EEG = pop_chanedit(EEG, 'load', {char(f2l.elocs),'filetype','autodetect'});
                EEG.chaninfo.nodatchans(1).labels = 'NZ'; % This is specific to this dataset, as chanlocs are not imported correctly in the first place.
                EEG.chaninfo.nodatchans(2).labels = 'LPA';
                EEG.chaninfo.nodatchans(3).labels = 'RPA';
                EEG_INCR(incrNum) = update_EEG(EEG, ICA_INCR(incrNum), true, 1);
            end
        end
    end
end

%% incremental dipfit
% saving takes way more than running the loop. NEVER save here. But, if you
% include the icalble processing in the saved dataset, then it worths
% saving.
if ~exist(f2l.classify, 'file') || ~load_existing
    m = gcp('nocreate');
    if isempty(m) || m.NumWorkers < 2
        try
            parpool('local',20);
            m = gcp('nocreate');
        catch
            warning('incremental dipfit is running non-parallel. This may take up to a day')
            m.NumWorkers = 0;
        end
    end
    parfor (i = 1:length(EEG_INCR), m.NumWorkers)
    EEG_INCR(i) =  pop_dipfit_settings(EEG_INCR(i),'hdmfile',char(f2l.HDM),'mrifile',char(f2l.MRI),...
        'chanfile',char(f2l.chan),'coordformat','MNI','chansel', 1:EEG_INCR(i).nbchan); %#ok<PFBNS>

    % for more datail on why we only use fiducials, see: J3P17
    [~,EEG_INCR(i).dipfit.coord_transform] = coregister(EEG_INCR(i).chanlocs,EEG_INCR(i).dipfit.chanfile,...
        'chaninfo1', EEG_INCR(i).chaninfo,'mesh',EEG_INCR(i).dipfit.hdmfile,'warp',{'NZ' 'RPA' 'LPA'}, 'manual', 'off');

         EEG_INCR(i) = pop_multifit(EEG_INCR(i), [] , 'threshold',100, 'plotopt',{ 'normlen', 'on'});
    end
    for i = 1:length(EEG_INCR)
       EEG_INCR(i).subject = [EEG_INCR(i).subject '_' num2str(i)];
    end


    %% select the most diverse increment
    % find which increment has the most brain components with low r.v., so, we
    % should first find the low RV componenets, determine if the dipoles are
    % inside the brain. Finding the BA and the dataset that has the most diverse
    % BA distribution is not wise right of the bat because many of those
    % components turn out to be muscle. Therefore, let's first have ICLABEL
    % find the datasets with the most brain componenets, then, if there is more
    % than one left, let's find the one with the most diverse BA distribution.
    f = waitbar(0,'finding incremental ICA labels','Name','please be patient');
    for i = 1:length(EEG_INCR)
        EEG_INCR(i) = iclabel(EEG_INCR(i), 'default');
        waitbar(i/length(EEG_INCR),f)
    end
    close(f);
    
    for i = 1:length(EEG_INCR)
        ICA_INCR(i).dipfit = EEG_INCR(i).dipfit;
        EEG_INCR(i) = talLookup(EEG_INCR(i),[],p2l.codebase+"funcs/general/");
        ICA_INCR(i).tal_dipfit = EEG_INCR(i).dipfit;
        ICA_INCR(i).classification = EEG_INCR(i).etc.ic_classification;     
    end
    save(f2l.classify, "ICA_INCR")

else
    load(f2l.classify, "ICA_INCR")
end

for i = 1:length(EEG_INCR)
    if ~isfield(EEG_INCR(i), 'dipfit') || isempty(EEG_INCR(i).dipfit)
        EEG_INCR(i).dipfit = ICA_INCR(i).tal_dipfit;
        EEG_INCR(i).etc.ic_classification = ICA_INCR(i).classification;
    end
    lowRV_inBrain = eeg_dipselect(EEG_INCR(i),rv,'inbrain');
    brainComps = []; % components identified as brain by ICLABEL
    for j = 1:length(EEG_INCR(i).dipfit.model)
        if max(EEG_INCR(i).etc.ic_classification.ICLabel.classifications(j,:)) == ...
                EEG_INCR(i).etc.ic_classification.ICLabel.classifications(j,1)
            brainComps = [brainComps j];
        end
    end
    goodComps{i} = brainComps(ismember(brainComps, lowRV_inBrain));
    goodCompLength(i) = length(goodComps{i});
    ICA_INCR(i).incr_comps = lowRV_inBrain;
end

%% find the increment with the most brain components
uniqueCount = sort(unique(goodCompLength),"descend");
good_incr_ind = find(ismember(goodCompLength,uniqueCount(1:3)));

if length(good_incr_ind) > 1
    diverseINCR = good_incr_ind(floor(length(good_incr_ind)/2)+1);
else
    diverseINCR = good_incr_ind;
end

ICA_STRUCT = ICA_INCR(diverseINCR);
EEG_out = EEG_INCR(diverseINCR);
%% creat a summary of the incremental dipoles & store in ICA_STRUCT
for i = 1:length(ICA_INCR)
    ICA_STRUCT.incr_info.tal_dipfit(i) = ICA_INCR(i).tal_dipfit;
    ICA_STRUCT.incr_info.classification(i) = ICA_INCR(i).classification;
    ICA_STRUCT.incr_info.lowRV_inBrain_comps{i} = ICA_INCR(i).incr_comps;
end
ICA_STRUCT.most_brain_increments.candidate = good_incr_ind;
ICA_STRUCT.most_brain_increments.selected_incr = diverseINCR;
% for i = 1:length(STUDY.cluster), ICA_STRUCT.incr_cluster(i) = STUDY.cluster(i); end
