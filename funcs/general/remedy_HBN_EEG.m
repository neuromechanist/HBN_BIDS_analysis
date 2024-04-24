function [unav_dataset, unav_dataset_idx, error_message, error_stack, quality_table] = remedy_HBN_EEG(f2l, data, p2l, dpath, remediedrepo)
unav_dataset = [];
unav_dataset_idx = [];
error_message = [];
error_stack = {};
key_events = load("key_events.mat");
if exist(f2l.quality_table,"file"), load(f2l.quality_table, "quality_table"); else, quality_table = table(); end
% quality_table = table();
for i = 1:length(data)
    try
        EEG = [];
        subj = string(data(i).subject);
        eeg_set_names = data(i).set_name;
        for n = eeg_set_names
            p2l.rawEEG = p2l.raw + string(data(i).subject) + dpath;
            tempload = load(p2l.rawEEG + data(i).raw_file(n==eeg_set_names));
            EEG.(n) = tempload.EEG;
            behavior_dir = p2l.raw + string(data(i).subject) + "/Behavioral/mat_format/";
            disp("loaded "+p2l.rawEEG + data(i).raw_file(n==eeg_set_names))
        end

    p2l.rawEEG_updated = remediedrepo + string(data(i).subject) + dpath;
    if ~exist(p2l.rawEEG_updated, "dir"), mkdir(p2l.rawEEG_updated); end
    for n = string(fieldnames(EEG))'
        EEG.(n).setname = char(subj + "_" + n);
        EEG.(n).subject = char(subj);
        EEG.(n) = eeg_checkset(EEG.(n));
        EEG.(n) = pop_chanedit(EEG.(n), 'load', {char(f2l.elocs),'filetype','autodetect'});
        EEG.(n) = pop_chanedit(EEG.(n), 'setref',{'1:129','Cz'});
        [EEG.(n).event.latency] = deal(EEG.(n).event.sample);
        EEG.(n) = remove_brcnt(EEG.(n)); % remove data and event correpnding to break_cnt (see issue #6)
        EEG.(n) = replace_event_type(EEG.(n), 'funcs/tsv/lookup_events.tsv', 1, 1);
        EEG.(n) = augment_behavior_events(EEG.(n), data(i).raw_file(n==string(fieldnames(EEG))'), behavior_dir);
        EEG.(n) = eeg_checkset(EEG.(n), 'makeur');
        EEG.(n) = eeg_checkset(EEG.(n), 'chanlocs_homogeneous');
        quality_table = run_quality_metrics(EEG.(n), n, quality_table, key_events, 0);
        % save the remedied EEG structure.
        pop_saveset(EEG.(n), 'filename', char(n), 'filepath', char(p2l.rawEEG_updated));
        disp("saved the remedied file for " + n)
    end
    catch ME
        error_message = [error_message; string([ME.identifier, ME.message])];
        error_stack{end+1} = ME.stack;
        unav_dataset = [unav_dataset, string(data(i).subject)];
        unav_dataset_idx = [unav_dataset_idx i];
        warning("data from " +string(data(i).subject)+" is not available, removing corresponding entries")   
    end       
end
end