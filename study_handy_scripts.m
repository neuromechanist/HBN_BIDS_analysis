%% paths
addpath('eeglab')
addpath(genpath('HBN_BIDS_analysis'))
eeglab; close;
study_path = "/expanse/projects/nemar/yahya/hbn_bids_R3/";
out_path = "/Volumes/S1/R3 derivatives/thepresent/"; %"/expanse/projects/nemar/yahya/R3_derivatives/thepresent/";  % thepresent or eeglab_test_redo
ica_path = out_path + "amica_tmp/";
mkdir(ica_path)
img_path = out_path + "img/";
mkdir(img_path)

new_study = 0; % set it to 1 to load the data  from scratch
study_stage_toLoad  = "_clustered";  % Choices are ["", "_amica", "_iclabel", "_summarized", "_epcohed", "_clustered"]

run_fresh_AMICA = 0; % There might be old wieghts to use, if set to one, it will re-run for all, if set to zero, will only do for those not available.
% In order to have a more robust ICA, tasks groups can concatenate the data, but later, only the target task will be analyzed.
task_group = ["surroundSupp"    "RestingState"    "DespicableMe"    "ThePresent"    "FunwithFractals"    "DiaryOfAWimpyKid"];
target_task = "ThePresent"; target_run = [1]; epochs_of_interest = {'shots'};

if length(target_run) > 1
    for i = target_run
        taskRun = target_task + "_" + string(i);
    end
else
    taskRun = target_task;
end
%% load the bids dataset
if new_study
    [STUDY, ALLEEG] = pop_importbids(char(study_path), 'eventtype','value','bidsevent','on','bidschanloc','off', 'outputdir',char(out_path),...
        'bidstask', cellstr(task_group), 'studyName',char(target_task));
    CURRENTSTUDY = 1; EEG = ALLEEG; CURRENTSET = [1:length(EEG)];
else
% or alternatively load the study
    [STUDY ALLEEG] = pop_loadstudy('filename', char(target_task+study_stage_toLoad+".study"), 'filepath', char(out_path));
    CURRENTSTUDY = 1; EEG = ALLEEG; CURRENTSET = [1:length(EEG)];
end

%% Identify datasets with avaialble tag
available_idx = lookup_dataset_info(STUDY, 1, 1:length(taskRun), taskRun, "available", "subject");

available_subjs = unique(intersect_multiple(available_idx));
% ensure that available_subjs is a row vector
available_subjs = available_subjs(:)';

%% keep only available subjects
[STUDY, ALLEEG] = std_rmdat(STUDY, ALLEEG, 'keepvarvalues', {'subject', cellstr(available_subjs)});
EEG = ALLEEG;

% save study
[STUDY ALLEEG] = std_editset(STUDY, ALLEEG, 'name',char(target_task));
[STUDY EEG] = pop_savestudy(STUDY, EEG, 'savemode','resave');
CURRENTSTUDY = 1; ALLEEG = EEG; CURRENTSET = [1:length(EEG)];

%% clean channel data
pop_editoptions('option_parallel', 1);
EEG = pop_eegfiltnew(EEG, 1, 0); % Highpass at 1 Hz, and Lowpass 0 Hz.

EEG = pop_cleanline(EEG, 'bandwidth',2,'chanlist',1:128,...
        'computepower',1,'linefreqs',[60 120 180] ,'normSpectrum',0,'p',0.05,'pad',2,'plotfigures',0,...
        'scanforlines',1,'sigtype','Channels','tau',100,'verb',1,'winsize',4,'winstep',1, 'newversion', true);
EEG = pop_cleanline(EEG, 'bandwidth',2,'chanlist',1:128,...
        'computepower',1,'linefreqs',[60 120 180] ,'normSpectrum',0,'p',0.05,'pad',2,'plotfigures',0,...
        'scanforlines',1,'sigtype','Channels','tau',100,'verb',1,'winsize',4,'winstep',1, 'newversion', true);

EEG = pop_clean_rawdata(EEG, 'FlatlineCriterion','off','ChannelCriterion',0.8,'LineNoiseCriterion',5,'Highpass','off','BurstCriterion','off','WindowCriterion','off','BurstRejection','off','Distance','Euclidian','fusechanrej',1);
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, [1:length(EEG)] ,'study',1); 
STUDY = std_checkset(STUDY, ALLEEG);

[STUDY EEG] = pop_savestudy(STUDY, EEG, 'savemode','resave');
CURRENTSTUDY = 1; ALLEEG = EEG; CURRENTSET = [1:length(EEG)];

%% concatenate same-subject/task runs and run AMICA
if run_fresh_AMICA
    parfor (s = 1:length(available_subjs), 24)
        [~, temp_EEG] = std_rmdat(STUDY, ALLEEG, 'keepvarvalues', {'subject', cellstr(available_subjs(s))});
        temp_mergedEEG = pop_mergeset(temp_EEG, 1:length(temp_EEG));

        runamica17_nsg(temp_mergedEEG, 'outdir', char(ica_path+available_subjs(s)),...
            'do_reject', 1, 'numrej', 5, 'rejsig', 4);
    end
end

%% Check if AMICA redsults exists and re-run AMICA
% Current AMICA may freeze in 5 to 10% of the cases. Therefore, we need to
% ensure that were completed.
for s = 1:length(available_subjs)
    if ~exist(ica_path+available_subjs(s), "dir") || ~exist(ica_path+available_subjs(s)+"/W", "file")
        warning("AMICA did not run for subject "+available_subjs(s)+", trying to rerun AMICA!")
        [~, temp_EEG] = std_rmdat(STUDY, ALLEEG, 'keepvarvalues', {'subject', cellstr(available_subjs(s))});
        temp_mergedEEG = pop_mergeset(temp_EEG, 1:length(temp_EEG));

        runamica17_nsg(temp_mergedEEG, 'outdir', char(ica_path+available_subjs(s)),...
            'do_reject', 1, 'numrej', 5, 'rejsig', 4);
    end
end

%% load the ICA weights
% find the EEG data for each subject and update the weights.
unav_amica = [];
EEG_subjs = string({EEG(:).subject});
for s = available_subjs
    try
        idx = find(EEG_subjs==s);
        for i = idx
            EEG(i) = eeg_loadamica(EEG(i), char(ica_path + s), 1);
        end
    catch
        unav_amica = [unav_amica s]; %#ok<AGROW> 
    end
end

[ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);
[STUDY EEG] = pop_savestudy(STUDY, EEG, 'savemode','resavegui');
CURRENTSTUDY = 1; ALLEEG = EEG; CURRENTSET = [1:length(EEG)];

%% save new study with the subjs that have AMICA wieghts
[STUDY, ALLEEG] = std_rmdat(STUDY, ALLEEG, 'rmvarvalues', {'subject', cellstr(unav_amica)});
EEG = ALLEEG;
[STUDY EEG] = pop_savestudy( STUDY, EEG, 'filename',char(target_task+"_amica"+".study"),'filepath',char(out_path), 'resavedatasets', 'on');
CURRENTSTUDY = 1; ALLEEG = EEG; CURRENTSET = [1:length(EEG)];

% update available subjects
available_idx = lookup_dataset_info(STUDY, 1, 1:length(taskRun), taskRun, "available", "subject");

available_subjs = unique(intersect_multiple(available_idx));
% ensure that available_subjs is a row vector
available_subjs = available_subjs(:)';

%% Perform dipfit
elocs = "GSN_HydroCel_129_AdjustedLabels.sfp";
HDM = "eeglab/plugins/dipfit5.4/standard_BEM/standard_vol.mat";
MRI = "eeglab/plugins/dipfit5.4/standard_BEM/standard_mri.mat";
chan = "eeglab/plugins/dipfit5.4/standard_BEM/elec/standard_1005.elc";
EEG_subjs = string({EEG(:).subject});

for s = available_subjs
    idx = find(EEG_subjs==s);
    for i = idx
        if i == idx(1) % run dipfit
            EEG(i) = pop_dipfit_settings(EEG(i), 'hdmfile', char(HDM), 'mrifile', char(MRI),...
                'chanfile', char(chan), 'coordformat', 'MNI', 'chansel', 1:EEG(i).nbchan, ...
                'coord_transform',[0.054411 -17.3649 -8.1316 0.075498 0.0031872 -1.5696 11.7145 12.7934 12.213]);
            % The cooridnation transform comes from once doing the
            % registration and warping manually with Cz, Nz, LPA, and RPA.
        
            EEG(i) = pop_multifit(EEG(i), [] , 'threshold',100, 'plotopt',{'normlen', 'on'});
        else
            EEG(i).dipfit = EEG(idx(1)).dipfit;

            % also save the structure for later use
            dipfit = EEG(i).dipfit;
            save(ica_path+s+string(filesep)+s+"_dipfit.mat", "-struct", "dipfit");
        end
    end
end
[ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);
[STUDY EEG] = pop_savestudy(STUDY, EEG, 'resavedatasets', 'on');
[EEG, ALLEEG, CURRENTSET] = eeg_retrieve(EEG, 1:length(EEG));

%% run ICLABEL
pop_editoptions('option_parallel', 0);
EEG = pop_iclabel(EEG, 'default');

[STUDY EEG] = pop_savestudy(STUDY, EEG, 'savemode','resavegui');
[EEG, ALLEEG, CURRENTSET] = eeg_retrieve(EEG, 1:length(EEG));

%% ICLABEL rejection
pop_editoptions( 'option_parallel', 0);
EEG = pop_icflag(EEG, [0 0.69;0 NaN;NaN NaN;NaN NaN;NaN NaN;NaN NaN;NaN NaN]);
[ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);
% Check if there is a subject with all comps rejected, then we shoul remove
% that subject

EEG_subjs = unique(string({EEG(:).subject}));
nobrain_subjs = [];
for s = EEG_subjs
    idx = find(string({EEG(:).subject})==s);
    for i = idx
        if isempty(find(EEG(i).reject.gcompreject == 0))
            warning("subject " + s + " does not have any Brain comps according to ICLABEL, removing the subjs from STUDY")
            nobrain_subjs = [nobrain_subjs, s];
            break;
        end
        STUDY.datasetinfo(i).comps = find(EEG(i).reject.gcompreject == 0)';
    end    
end
if ~isempty(nobrain_subjs)
    [STUDY, ALLEEG] = std_rmdat(STUDY, ALLEEG, 'rmvarvalues', {'subject', cellstr(nobrain_subjs)});
end
[EEG, ALLEEG, CURRENTSET] = eeg_retrieve(ALLEEG, 1:length(ALLEEG));
[STUDY EEG] = pop_savestudy(STUDY, EEG, 'resavedatasets', 'on');

% Let's see how many components will remain
% this checks EEG.reject structure
kept_comps = [];
for i = 1:length(EEG)
    kept_comps = [kept_comps length(find(EEG(i).reject.gcompreject==0))];
end
disp("total kept comps in EEG.reject:" + sum(kept_comps)/length(STUDY.run) + ", mean:" + string(mean(kept_comps)) +", std:"+ string(std(kept_comps)));

% this checks datasetinfo
kept_comps = [];
for i = 1:length(EEG)
    kept_comps = [kept_comps length(STUDY.datasetinfo(i).comps)];
end
disp("total kept comps in datasetinfo:" + sum(kept_comps)/length(STUDY.run) + ", mean:" + string(mean(kept_comps)) +", std:"+ string(std(kept_comps)));

% recreate parent cluster
STUDY.cluster = [];
STUDY = std_createclust(STUDY, ALLEEG, 'parentcluster', 'on');

[STUDY EEG] = pop_savestudy( STUDY, EEG, 'filename',char(target_task+"_iclabel"+".study"),'filepath',char(out_path), 'resavedatasets', 'on');
CURRENTSTUDY = 1; ALLEEG = EEG; CURRENTSET = [1:length(EEG)];
%% Create a new study if task_group and target_task are not the same
task_idx = lookup_dataset_info(STUDY, 1 , 1:length(taskRun), repmat("task",1,length(taskRun)), target_task);
task_idx = union_multiple(task_idx); task_idx = task_idx(:)';

all_idx = [STUDY.datasetinfo(:).index];

rmv_idx = all_idx(~ismember(all_idx, task_idx));

[STUDY, ALLEEG] = std_rmdat(STUDY, ALLEEG, 'datinds', rmv_idx);
EEG = ALLEEG;
STUDY = std_checkset(STUDY, ALLEEG);

[STUDY EEG] = pop_savestudy( STUDY, EEG, 'filename',char(target_task+"_summarized"+".study"),'filepath',char(out_path), 'resavedatasets', 'on');
CURRENTSTUDY = 1; ALLEEG = EEG; CURRENTSET = [1:length(EEG)];

%% Insert the events if needed
expand_table = "the_present_stimulus-LogLumRatio.tsv";
unav_expansion = [];
for e = 1:length(EEG)
    try
        EEG(e) = expand_events(EEG(e), expand_table, ["shot_number", "LLR"],'shots', 0, 1);
    catch
        unav_expansion = [unav_expansion e];
    end
end
ALLEEG = EEG;

[STUDY, ALLEEG] = std_rmdat(STUDY, ALLEEG, 'datinds', unav_expansion);
EEG = ALLEEG;
STUDY = std_checkset(STUDY, ALLEEG);

%% Epoch
% First identify target_task index
[STUDY EEG] = pop_savestudy( STUDY, EEG, 'filename',char(target_task+"_epoched"+".study"),'filepath',char(out_path), 'resavedatasets', 'on');
[EEG, ALLEEG, CURRENTSET] = eeg_retrieve(EEG, 1:length(EEG));

EEG = pop_epoch( EEG, epochs_of_interest, [-0.6 0.6] ,'epochinfo','yes');

[STUDY EEG] = pop_savestudy(STUDY, EEG, 'resavedatasets', 'on');
[EEG, ALLEEG, CURRENTSET] = eeg_retrieve(EEG, 1:length(EEG));

%% precompute
pop_editoptions('option_parallel', 1);
[STUDY, ALLEEG] = std_precomp(STUDY, ALLEEG, 'components','spec','on','allcomps', 'on', ...
    'specparams', {'specmode', 'psd', 'logtrials', 'off', 'freqrange',[3 80]},'recompute','off');

%% 
[STUDY, ALLEEG] = std_precomp(STUDY, ALLEEG, 'components','scalp','on', 'allcomps', 'on', 'recompute','off');
%%
pop_editoptions('option_parallel', 1);
[STUDY, ALLEEG] = std_precomp(STUDY, ALLEEG, 'components','ersp','on','allcomps', 'on', 'erspparams',{'cycles',[3 0.5],'alpha',0.05, 'padratio',2,'baseline',NaN,...
    'freqs', [3 100]},'recompute','off');

%% create preclustering array
STUDY = std_createclust(STUDY, ALLEEG, 'parentcluster', 'on');  % Update the parent cluster array, especially required if componenets have been changed.
[STUDY ALLEEG] = std_preclust(STUDY, ALLEEG, 1,...
    {'spec','npca',3,'weight',1,'freqrange',[3 70] },...
    {'scalpLaplac','npca',3,'weight',1,'abso',0},...
    {'dipoles','weight',10},'parentclust');

%% run optimal k-means using GUI or with 29 clusters and 3std oultiers below


%% plot the summary
STUDY = std_dipplot(STUDY,ALLEEG,'clusters',2:length(STUDY.cluster), 'design', 1, 'compBA', 'on');

%% plot the components
% Clusters with >50% subjects (>80 subjects)
clustinfo_major = table;
clustinfo_major(1,:) = {3, "BA31/visual", rgb('MediumSeaGreen')}; % 98 subjs
clustinfo_major(2,:) = {10, "BA18/visual", rgb('SeaGreen')}; % 91 subjs
clustinfo_major(3,:) = {13, "BA40R/temporal", rgb('RoyalBlue')}; % 84 subjs
clustinfo_major(4,:) = {16, "BA6R-lateral/SMA", rgb('MediumPurple')}; % 81 subjs
clustinfo_major(5,:) = {17, "BA6R-medial/SMA", rgb('BlueViolet')}; % 80 subjs
clustinfo_major(6,:) = {18, "BA7L/temporal", rgb('CornflowerBlue')}; % 81 subjs
clustinfo_major(7,:) = {19, "BA37R/visual", rgb('ForestGreen')}; % 85 subjs

clustinfo_minor.Properties.VariableNames = ["num","BA","color"];

% Clusters with 70-79 subjects (still interesting)
clustinfo_minor = table;
clustinfo_minor(1,:) = {4, "BA6-4/SMA", rgb('DarkOrchid')}; % 75 subjs
clustinfo_minor(2,:) = {5, "BA32/ACC", rgb('Crimson')}; % 72 subjs
clustinfo_minor(3,:) = {8, "BA6L-medial/SMA", rgb('MediumOrchid')}; % 75 subjs
clustinfo_minor(4,:) = {20, "BA6L-anterior/SMA", rgb('Amethyst')}; % 70 subjs
clustinfo_minor(5,:) = {22, "BA39L/temporal", rgb('SteelBlue')}; % 77 subjs
clustinfo_minor(6,:) = {24, "BA31/ACC", rgb('FireBrick')}; % 77 subjs

clustinfo_minor.Properties.VariableNames = ["num","BA","color"];

% Determine the BA distribution
if isfield(STUDY.cluster,"BA")
    STUDY.cluster = clusterBAdist(STUDY.cluster, 3:24); % change the range according to your own results
end

%% Plot the 3D dipole locations
studyName = string(STUDY.task);
% first let's go for the cluster locations
clustView.axial = [0 0 1]; clustView.sagittal = [1 0 0];
clustView.coronal = [0 -1 0]; clustView.perspective = [1 -1 1];
fig = struct();

for p = transpose(string(fieldnames(clustView)))
    if isequal(p, "perspective"), centProjLine = 1; else, centProjLine = 0; end
    fig.(p) = diplotfig(STUDY, ALLEEG,transpose([clustinfo_minor.num]),...
        num2cell(clustinfo_minor.color,2) ,centProjLine,'view',clustView.(p),'gui','off', 'cornermri', 'on', 'drawedges', 'off'); 
end

for p = transpose(string(fieldnames(clustView)))
    for v = transpose(string(fieldnames(fig.(p))))
        print(fig.(p).(v), img_path + v+"_"+p+"_"+studyName+".pdf","-dpdf","-r300");
        print(fig.(p).(v), img_path + v+"_"+p+"_"+studyName+".png","-dpng","-r300");
    end
end

%% Plot the maps
studyName = string(STUDY.task);
for i = 1:height(clustinfo)
   std_topoplot(STUDY, ALLEEG, 'clusters', clustinfo_minor.num(i));
   fig.("c"+string(i)+"_topo") = get(groot,'CurrentFigure');
end

for i = 1:height(clustinfo)
    fN = "c"+string(i)+"_topo"; % fieldNames
    print(fig.(fN), img_path + fN + "_" + studyName + ".pdf","-dpdf","-r300");
    print(fig.(fN), img_path + fN + "_" + studyName + ".png","-dpng","-r300");
end

%% helper funcs
function result = intersect_multiple(cellArray)
    % Check if the input is a cell array
    if ~iscell(cellArray)
        error('Input must be a cell array.');
    end

    % Check if the cell array is empty
    if isempty(cellArray)
        result = []; % Return an empty array if there's nothing to intersect
        return;
    end

    % Initialize the result with the first vector in the cell array
    result = cellArray{1};

    % Iterate through the remaining vectors in the cell array and find the intersection
    for k = 2:length(cellArray)
        result = intersect(result, cellArray{k});
    end
    
    % Convert the result to an array if it is not already
    result = result(:);
end

function result = union_multiple(cellArray)
    % Check if the input is a cell array
    if ~iscell(cellArray)
        error('Input must be a cell array.');
    end

    % Check if the cell array is empty
    if isempty(cellArray)
        result = []; % Return an empty array if there's nothing to union
        return;
    end

    % Initialize the result as an empty vector
    result = [];

    % Iterate through each vector in the cell array and find the union
    for k = 1:length(cellArray)
        result = union(result, cell2mat(cellArray{k}));
    end
    
    % Convert the result to an array if it is not already
    result = result(:);
end