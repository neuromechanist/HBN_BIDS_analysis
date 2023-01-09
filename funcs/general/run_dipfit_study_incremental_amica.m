function ICA_STRUCT = run_dipfit_study_incremental_amica(EEG, p2l, f2l)
% runs DIPFIT on incremental amica and standard MNI model to get the most
% stable components and generates the ICA_STRUCT with those components.
%
%
% REV:
%       v0 @ 5/27/2019 inception
%
% Created by: Seyed Yahya Shirazi, BRaIN Lab, UCF
% email: shirazi@ieee.org
%
% Copyright 2019 Seyed Yahya Shirazi, UCF, Orlando, FL 32826

%% initialize
fs = string(filesep);
if ~exist("p2l","var") || isempty(p2l.ICA)
    error("ICA path is mandatory");
end

p2l.incr0 = p2l.ICA + "incr0" + fs;
p2l.incrResults = p2l.ICA + "incr0" + fs + "incr_results" + fs;
if ~isfolder(p2l.incrResults), mkdir(p2l.incrResults); end

%% need ICA_INCR to update incremental ICA_STRUCTs
incr0Dir = dir(p2l.incr0);
incr0Content = string({incr0Dir(:).name});
load(p2l.incr0 + incr0Content(contains(incr0Content,"channels_frames.mat")),"ICA_INCR");

% let's find channles that are present in every ICA
bad_chan = [];
for i = 1:128
    for j = 1:length(ICA_INCR) %#ok<NODEF>
       if ~ismember(i,ICA_INCR(j).good_chans)
           bad_chan(end+1) = i;
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
                modout = loadmodout10(char(p2l.ICA + i + fs + "amicaout"));
                disp("imported ICA parpmeter for incr. " + string(incrNum));
                ICA_INCR(incrNum).weights = modout.W;
                ICA_INCR(incrNum).sphere = modout.S;
%                 ICA_INCR(incrNum).inverse = modout.A;
                EEG_INCR(incrNum) = update_EEG(EEG,ICA_INCR(incrNum));
                EEG_INCR(incrNum).filename = [EEG_INCR(incrNum).filename(1:end-3) '_' num2str(incrNum) '.set'];
                EEG_INCR(incrNum).filepath = char(p2l.incrResults);
            end
        end
    end
end

%% incremental dipfit
% saving takes way more than running the loop. NEVER save here.
try parpool('local',20); catch, end
parfor i = 1:length(EEG_INCR)
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

%% Reject dipoles that have RV > 0.15
% these sources will not help the study anyway, so removing them should
% help the clustering and making up our mind how to treat the remaining
% dipoles.
% UPDATE: seems that using NFT is not feasible becasue of slow dipfit
% analysis, so there is not reason to reject RV > 0.15 here, let's just do
% it EEGLAB's std_editset.

% for i = 1:length(EEG_INCR)
%     EEG_INCR(i).dipfit.original_model = EEG_INCR(i).dipfit.model;
%     EEG_INCR(i).dipfit.model([EEG_INCR(i).dipfit.model(:).rv]>.15) = [];
%     len.model(i) = length(EEG_INCR(i).dipfit.model);
% end

%% create study
[STUDY, EEG_INCR] = eeg_retrieve(EEG_INCR,1);
[STUDY, EEG_INCR] = std_editset(STUDY, EEG_INCR, 'name','incr_clust','updatedat','on','rmclust','off','commands',{'dipselect',0.20});
[STUDY, EEG_INCR] = std_checkset(STUDY, EEG_INCR);
[STUDY, EEG_INCR] = std_precomp(STUDY, EEG_INCR, 'components','allcomps','on','recompute','on','scalp','on','spec','on','specparams',{'specmode' 'psd' 'logtrials' 'off'});
[STUDY, EEG_INCR] = std_preclust(STUDY, EEG_INCR, 1,{'spec' 'npca' 10 'weight' 1 'freqrange' [3 25] },{'dipoles' 'weight' 10});
for i = 1:length(STUDY.datasetinfo), nComps(i) = length(STUDY.datasetinfo(i).comps); end
STUDY = pop_clust(STUDY, EEG_INCR, 'algorithm','optimal_kmeans','clus_num', [ceil(min(nComps)/2),max(nComps)]);

for i = 2:length(STUDY.cluster)
STUDY = std_dipplot(STUDY,EEG_INCR,'clusters',i,'view',[1 -1 1]);
saveas(gcf,p2l.incr0 + "figs" + fs + "cluster_" + string(i) + ".fig");
saveas(gcf,p2l.incr0 + "figs" + fs + "cluster_" + string(i) + ".png");
close all
end

%% pick representative compomnent from the clusters
% We need to find clusters that has compoenets from the apparent majority
% of the ICA steps (20/32 = 63%), keeping centroid dipoles' centroid, moment
% and r.v. but retaining the componenet witht he highest variance.

n = 0;
for i = 2:length(STUDY.cluster)
    if STUDY.cluster(i).dipole.rv < 0.15
        if length(unique(STUDY.cluster(i).sets)) > 20
            n = n + 1;
            tempComp(n).name = STUDY.cluster(i).name;
            tempComp(n).numSets = length(unique(STUDY.cluster(i).sets));
            tempComp(n).numComps = length(STUDY.cluster(i).comps);
            tempComp(n).dipole = STUDY.cluster(i).dipole;
            for j = 1:length(STUDY.cluster(i).comps)
                compStd(j) = std(EEG_INCR(STUDY.cluster(i).sets(j)).icaact(STUDY.cluster(i).comps(j),:));          
            end
            [~,selComp] = min(compStd); % selected compoenent;
%             [~, stdInd] = 
            tempComp(n).set = STUDY.cluster(i).sets(selComp);
            tempComp(n).comp = STUDY.cluster(i).comps(selComp);
            tempComp(n).good_chan = {[EEG_INCR(tempComp(n).set).chanlocs(:).urchan]};
            clear selComp compStd
        end
    end
end
%% create modified spehre and demixing matrix
% Each component can potentially have a different set of channles
% contbuting to that component. So, we need to find all the componenets'
% channles and then have a sum sphere and weight matrix.
%%%%%%%%%%%%%%% THIS IS NOT WORKING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% I think the way I construct goodchans is not right, so this does not work
% for now, maybe I come back to make it right some day.

for i = unique([tempComp(:).set])
    incrWeightMatrix{i} = EEG_INCR(i).icaweights * EEG_INCR(i).icasphere;
end

allChan = [];
for i = 1:length(tempComp)
    tempComp(i).ica_WS = incrWeightMatrix{tempComp(i).set}(tempComp(i).comp,:);
    allChan = [allChan tempComp(i).good_chan{1}];
end
allChan = unique(allChan);

icaW = zeros(length(tempComp),length(allChan));
for i = 1:length(tempComp)
    for j = 1:length(tempComp(i).good_chan{1})
        icaW(i,allChan==tempComp(i).good_chan{1}(j)) = tempComp(i).ica_WS(j);
    end
end

aICA_STRUCT.good_chans = allChan;
aICA_STRUCT.chan_rej_method = 'incremental_rejection';
aICA_STRUCT.associated_set = ICA_INCR(1).associated_set;
aICA_STRUCT.chan_rej_frames_used = [];
aICA_STRUCT.ref = ICA_INCR(1).ref;
aICA_STRUCT.min_bad_frame_spacing  = ICA_INCR(1).min_bad_frame_spacing;
aICA_STRUCT.bad_frame_border_dur = ICA_INCR(1).bad_frame_border_dur;
aICA_STRUCT.weights = icaW;
aICA_STRUCT.sphere = eye(length(allChan));
aICA_STRUCT.dipfit = STUDY.dipfit; aICA_STRUCT.dipfit = rmfield(aICA_STRUCT.dipfit,'model');
aICA_STRUCT.dipfit.model = [tempComp.dipole]; %#ok<STRNU>

%% Alternative, find the increment that is common in every cluster
% as an alternative, let's find if any increment has a component in every
% cluster with rv < 0.15
for k = [20,24]
commINCR = 1:length(EEG_INCR);
for i = 2:length(STUDY.cluster)
    if STUDY.cluster(i).dipole.rv < 0.15
        if length(unique(STUDY.cluster(i).sets)) > k
            commINCR(~ismember(commINCR,unique(STUDY.cluster(i).sets))) = [];
        end
    end
end

% find which dipoles from the commn clusters we should keep
for i = commINCR
    commDip.("incr"+i) = [];
   for j =  2:length(STUDY.cluster)
       if STUDY.cluster(j).dipole.rv < 0.15
        if length(unique(STUDY.cluster(j).sets)) > k
            commDip.("incr"+i) = [commDip.("incr"+i) STUDY.cluster(j).comps(STUDY.cluster(j).sets == i)];
        end
       end
   end
end

if ~isempty(commINCR), break; end
end


for i = commINCR
    ICA_INCR(i).dipfit = EEG_INCR(i).dipfit;
    ICA_INCR(i).incr_comps = sort(commDip.("incr"+i));
    dipNum(i == commINCR) = length(ICA_INCR(i).dipfit.model);
end

ICA_STRUCT = ICA_INCR(commINCR(max(dipNum)==dipNum));
ICA_STRUCT.comm_dip_threshold = k/length(EEG_INCR);
%% creat a summary of the incremental dipoles & store in ICA_STRUCT
for i = 1:length(EEG_INCR),ICA_STRUCT.incr_dipfit(i) = EEG_INCR(i).dipfit; end
for i = 1:length(STUDY.cluster), ICA_STRUCT.incr_cluster(i) = STUDY.cluster(i); end
