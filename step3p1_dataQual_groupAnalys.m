function step3p1_dataQual_groupAnalys(participant_list, mergedSetName, platform, machine, load_setfiles, save_setfiles)
%STEP3P1_DATAQUAL_GROUPANALYS Summarizes results from step 3.
%   Following selecting the best increment for cleaning each dataset, we
%   need to run some group metrics to assess the cleaning and ICA
%   performance. The 
%
% (c) Seyed Yahya Shirazi, 03/2023 UCSD, INC, SCCN

%% initialize and adding paths
clearvars -except participant_list platform machine load_setfiles save_setfiles
close all; clc;
fs = string(filesep)+string(filesep);

if ~exist('platform','var') || isempty(platform), platform = "linux"; else, platform = string(platform); end
if ~exist('mergedSetName','var') || isempty(mergedSetName), mergedSetName = "everyEEG"; end
% if the code is being accessed from Expanse
if ~exist('machine','var') || isempty(machine), machine = "expanse"; else, machine = string(machine); end
p2l = init_paths(platform, machine, "HBN", 1, false);  % Initialize p2l and eeglab.
addpath(genpath(p2l.codebase))
if ~exist('participant_list', 'var') || isempty(participant_list)
    contents = dir(p2l.eegRepo);
    participant_list = string({contents.name});
    participant_list = participant_list(contains(participant_list,"NDAR"));
end
if ~exist('load_setfiles','var') || isempty(load_setfiles), load_setfiles = false; end
if ~exist('save_setfiles','var') || isempty(save_setfiles), save_setfiles = true; end
f2l.elocs = p2l.codebase + "funcs" + fs + "GSN_HydroCel_129_AdjustedLabels.sfp";

%% load ICA_structs
unavailable_participants = [];
for p = participant_list
    p2l.incr0 = p2l.eegRepo + p + fs + "ICA" + fs + "incr0" + fs;
    f2l.ICA_STRUCT.(p) = p2l.incr0 + p + "_" + mergedSetName + "_ICA_STRUCT_rejbadchannels_diverse_incr_comps.mat";
    try
        ICA_STRUCT.(p) = load(f2l.ICA_STRUCT.(p));
    catch
        unavailable_participants = [unavailable_participants p];
        participant_list(participant_list==p) = [];
    end
end

%% load EEG files as well
% Only run this section if the finls set files with channel and frame
% rejection are NOT available.
if load_setfiles
    f = waitbar(0,'updating the set files with frame rejections','Name','please be patient');
    for p = participant_list
        p2l.EEGsets.(p) = p2l.eegRepo+ p + fs + "EEG_sets" + fs; % Where .set files are saved
        f2l.alltasks.(p) = p + "_" + mergedSetName + ".set"; % as an Exception, path is NOT included
        f2l.alltasks_cleaned.(p) = p + "_" + mergedSetName + "_stepwiseCleaned.set";
        %     if ~exist(p2l.EEGsets.(p) + f2l.alltasks_cleaned.(p), 'file')
        EEG = [];
        EEG = pop_loadset( 'filename', char(f2l.alltasks.(p)), 'filepath', char(p2l.EEGsets.(p)));
        EEG = pop_chanedit(EEG, 'load', {char(f2l.elocs),'filetype','autodetect'});
        
        % Update to concatenated data w/o frame rejection
        EEG = update_EEG(EEG, ICA_STRUCT.(p), false, 1, true);
        % update the set file with the frame rejection
        rejFrame = [];
        rejFrame.raw = ICA_STRUCT.(p).rej_frame_idx; % temporary rejected frames
        rejFrame.rowStart = [1 find(diff(rejFrame.raw) > 2)+1];
        for j = 1:length(rejFrame.rowStart)-1
            rejFrame.final(j,:) = [rejFrame.raw(rejFrame.rowStart(j)) rejFrame.raw(rejFrame.rowStart(j+1)-1)];
        end
        EEG = eeg_eegrej(EEG,rejFrame.final);
        
        if save_setfiles
            EEG.setname = char(f2l.alltasks_cleaned.(p));
            pop_saveset(EEG, 'filename', EEG.setname, 'filepath', char(p2l.EEGsets.(p)), 'savemode', 'twofiles');
        end
        %     end
        waitbar(find(participant_list==p)/length(participant_list),f)
    end
    close(f)
end

%% now let's run ICLABEL on the datasets, and augment ICA_STRUCT
% Only run if the ICASTRUCT does not have the classification field already. Newer
% implementations have it from step 3. The script below already checks that
% and skips running ICLABEL if it is already available. 
f = waitbar(0,'adding iclabel','Name','please be patient');
for p = participant_list
    if ~isfield(ICA_STRUCT.(p), 'calssification')
        EEG = [];
        EEG = pop_loadset( 'filename', char(f2l.alltasks_cleaned.(p)), 'filepath', char(p2l.EEGsets.(p)));
        EEG = pop_chanedit(EEG, 'load', {char(f2l.elocs),'filetype','autodetect'});
        EEG.nbchans = length(EEG.chanlocs);
        EEG = eeg_checkset(EEG);
        
        EEG = iclabel(EEG, 'default');
        EEG = talLookup(EEG);
        ICA_STRUCT.(p).iclabel = EEG.etc.ic_classification;
        ICA_STRUCT.(p).tal_dipfit = EEG.dipfit;
        temp_ict = ICA_STRUCT.(p);
        if save_setfiles
            save(f2l.ICA_STRUCT.(p), "temp_ict")
        end
    end
    waitbar(find(participant_list==p)/length(participant_list),f)
end
close(f)

%% aggregate coarse metrics
rej_elec_count = [];
rej_frame_ratio = [];
k = [];
incr_number = [];
braincomps = struct;
braincomp_count = struct;
original_numchans = 128; 
for p = participant_list
    rej_elec_count(end+1) = original_numchans-length(ICA_STRUCT.(p).good_chans);
    rej_chans.(p) = setdiff(1:128,ICA_STRUCT.(p).good_chans);
    rej_frame_ratio(end+1) = ICA_STRUCT.(p).percent_frames_bad;
    k(end+1) = ICA_STRUCT.(p).k;
    incr_number(end+1) = ICA_STRUCT.(p).most_brain_increments.selected_incr;

    braincomps.(p).ninety = find(ICA_STRUCT.(p).classification.ICLabel.classifications(:,1)>0.9);
    braincomps.(p).eighty = find(ICA_STRUCT.(p).classification.ICLabel.classifications(:,1)>0.8);
    braincomps.(p).seventy = find(ICA_STRUCT.(p).classification.ICLabel.classifications(:,1)>0.7);
    braincomps.(p).sixty = find(ICA_STRUCT.(p).classification.ICLabel.classifications(:,1)>0.6);
    braincomp_count.ninety(participant_list==p) = length(braincomps.(p).ninety);
    braincomp_count.eighty(participant_list==p) = length(braincomps.(p).eighty);
    braincomp_count.seventy(participant_list==p) = length(braincomps.(p).seventy);
    braincomp_count.sixty(participant_list==p) = length(braincomps.(p).sixty);
end

%% create the component-count table
braincomp_count.summary = table('Size',[length(participant_list), 5],'VariableTypes',["string", repmat("int16",[1,4])],'VariableNames',["subject", "sixty", "seventy", "eighty", "ninety"]);
braincomp_count.summary.subject = participant_list';
for p = ["sixty", "seventy", "eighty", "ninety"]
    braincomp_count.summary.(p) = braincomp_count.(p)';
end

[~,sort_index] = sort(braincomp_count.seventy,'descend');
braincomp_count.sorted_summary = braincomp_count.summary(sort_index, :);

writetable(braincomp_count.sorted_summary, "~/_git/HBN_BIDS_analysis/funcs/tsv/sorted_participants_70p_164.tsv",...
    "FileType","text","Delimiter","\t","WriteVariableNames",true,"LineEnding",'\n')

writetable(braincomp_count.sorted_summary(:,"subject"), "~/_git/HBN_BIDS_analysis/funcs/tsv/sorted_plistONLY_70p_164.txt",...
    "FileType","text","Delimiter","\t","WriteVariableNames",false,"LineEnding",'\n')
%% number of brain components
figure
boxplot([braincomp_count.ninety', braincomp_count.eighty', braincomp_count.seventy', braincomp_count.sixty'],'Notch','on','Labels',{'90%', '80%', '70%', '60%'},'Whisker',1)
title('number of brain components per ICLABEL classification (n=164)')
xlabel("probability of the dipole being Brain")
ylabel("number of dipoles")

%% Brodmann area distibution of the brian components
brain_percentage = ["sixty", "seventy", "eighty", "ninety"];
figure('Renderer', 'painters');
% tiledlayout(2,2, 'Padding', 'compact', 'TileSpacing', 'compact'); 
for b = brain_percentage
    local_brodmann = zeros(1,52); % first determine whcih BAs are represented for each person.
    for p = string(fieldnames(rej_chans))'
        bd_all_string = {ICA_STRUCT.(p).tal_dipfit.model(braincomps.(p).(b)).BA};
        bd_all_string(cellfun(@(x) length(x), bd_all_string)==0) = [];
        if ~isempty(bd_all_string)
            bd_string = cellfun(@(x) x(1), bd_all_string);
            bd = double(extract(bd_string, digitsPattern));
            local_brodmann(bd) = local_brodmann(bd) + 1;
        end
    end
    brodmann_dist.(b) = local_brodmann;
%     nexttile
%     bar(brodmann_dist.(b)(1:47))
%     title(b + " percent");
%     xlabel("BA");
%     xticks(1:47)
%     xticklabels(string(1:47))
%     xtickangle(45)
%     ylabel("number of subjects")
%     ylim([0,length(string(fieldnames(rej_chans)))])
end
% sgtitle("BA distribution across the group and brain-classification probablity")

brodmann_dist.stacked = [brodmann_dist.ninety',(brodmann_dist.eighty - brodmann_dist.ninety)',...
    (brodmann_dist.seventy - brodmann_dist.eighty)', (brodmann_dist.sixty - brodmann_dist.seventy)'];

bar(brodmann_dist.stacked, 'stacked');
xlabel("Brodmann Area");
xticks(1:47)
xlim([0.5 47.5])
xticklabels(string(1:47))
xtickangle(45)
ylabel("number of subjects")
ylim([0,length(string(fieldnames(rej_chans)))])
legend(fliplr(brain_percentage))
title("BA distribution across the group and brain-classification probability (n=154)")

set(gca,'box','off')

%% number of rejected elecrtods
figure
% boxplot(rej_elec_count,'Notch','on','Labels',{'number of rejected electrode'},'Whisker',1)
histogram(rej_elec_count,20)

title('number of rejected electrodes across subjes (n=164)')
ylabel('number of subjects')
xlabel('number of electrodes')

%% rejected electrode topoplot
% load a dummy EEG file
EEG = pop_loadset('filename','NDARAC853DTE_everyEEG.set','filepath','~/HBN_EEG/NDARAC853DTE/EEG_sets/');
EEG = pop_select(EEG, 'nochannel',129);
rej_count = zeros(1, original_numchans);
for p = string(fieldnames(rej_chans))'
    rej_count(rej_chans.(p)) = rej_count(rej_chans.(p)) + 1;
end
rej_count = rej_count * 5; % make the dots a little larger.

cl = floor((rej_count-min(rej_count)+1) /range(rej_count) * 255);
cl(cl>255) = 255;
cl(cl==0) = 1;
cmap = cool(255);

figure('Renderer','painters')
colormap cool
mod_topoplot([],EEG.chanlocs,'electrodes','on','emarker',{1:EEG.nbchan,'.',cmap(cl,:),rej_count,1})
colorbar
%% amount of frame rejection
figure
% boxplot(rej_frame_ratio,'Notch','on','Labels',{'Rejected frame percentage'},'Whisker',1)
histogram(rej_elec_count,20)

title('rejected frame percentage across subjes (n=164)')
ylabel('number of subjects')
xlabel('rejected data (%)')
