function [ALLEEG, STUDY] = expand_ica_toAll(ALLEEG, STUDY)

%% initialize
addpath('C:\_git\eeglab_fork')
addpath(genpath('C:\_git\HBN_BIDS_analysis\'))

input_dir = 'D:\lcoal_projects\ds005505_processed';
out_dir = 'D:\lcoal_projects\ds005505_processed/derivatives/eeglab';

eeglab; close;
%% load the data
[STUDY, ALLEEG] = pop_importbids(input_dir, 'bidsevent','off','bidschanloc','on','outputdir',out_dir);
CURRENTSTUDY = 1; EEG = 1;

%% for each subject, only one file (undert taskname combined has te ICA values adn cleaned channels, so we need to expand it to all the files)
subj_list = string({STUDY.datasetinfo.subject});
subj_list = unique(subj_list);
for s = subj_list
    % find the indices of the files for this subject
    idx = find(contains({STUDY.datasetinfo.subject}, s));
    % find the index of the file that has the ICA values
    idx_ica = find(contains({STUDY.datasetinfo(idx).task}, 'combined'));
    for i = idx
        if i == idx_ica
            continue
        end
        % change the current datasset to update the channle locations and ICA values
        EEG = eeg_retrieve(ALLEEG, i);
        EEG = pop_select(EEG, 'channel', {ALLEEG(idx_ica).chanlocs.labels});
        EEG.icaweights = ALLEEG(idx_ica).icaweights;
        EEG.icasphere = ALLEEG(idx_ica).icasphere;
        EEG.icawinv = ALLEEG(idx_ica).icawinv;
        EEG.icachansind = ALLEEG(idx_ica).icachansind;

        % save the updated dataset
        [ALLEEG, EEG, i] = eeg_store(ALLEEG, EEG, i);
        
    end
end
[EEG, ALLEEG, CURRENTSET] = eeg_retrieve(EEG, 1:length(EEG));

