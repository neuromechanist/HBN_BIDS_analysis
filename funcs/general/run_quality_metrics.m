function quality_table = run_quality_metrics(EEG, quality_table, save_table)
%RUN_QUALITY_CHECK quantifies simple quality metrics for BIDS EEG runs.
%   This function uqwanitfies simple quaLity-related metrics for the EEG
%   taski runs and saves (and append) them in a table. The quality metrics
%   include, (1) number of data points, (2) event count, (3) presence of
%   key events. The QUALITY_TABLE will be appended if it is provided.
%
% (c) Seyed Yahya Shirazi, 10/2023 SCCN, INC, UCSD

if ~exist("quality_table","var") || isempty(quality_table), quality_table = table(); end
if isstring(quality_table), quality_table = load(quality_table); end
if ~exist("save_table","var") || isempty(save_table), save_table = true; end
key_events = load("key_events.mat");
%% loop trhrough the tasks
for n = string(fieldnames(EEG))'
    subj = string(EEG.(n).subject);
    data_pnts = EEG.(n).pnts;
    event_cnt = length(EEG.(n).event);
    
    event_content = string({EEG.(n).event(:).type});
    key_events_exist = all(contains(key_events.(n),event_content));

    quality_table{subj,"participant_id"} = subj;
    quality_table{subj,n} = table(data_pnts,event_cnt,key_events_exist,...
        'VariableNames',["data_pnts","event_cnt","key_events_exist"]);
end

%% save the table
if save_table
    save("funcs/tsv/quality_table","quality_table");
end