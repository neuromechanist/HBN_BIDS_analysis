function quality_table = run_quality_metrics(EEG, quality_table)
%RUN_QUALITY_CHECK quantifies simple quality metrics for BIDS EEG runs.
%   This function uqwanitfies simple quaLity-related metrics for the EEG
%   taski runs and saves (and append) them in a table. The quality metrics
%   include, (1) number of data points, (2) event count, (3) presence of
%   key events. The QUALITY_TABLE will be appended if it is provided.
%
% (c) Seyed Yahya Shirazi, 10/2023 SCCN, INC, UCSD

if ~exist("quality_table","var") || isempty(quality_table), quality_table = table(); end
if isstring(quality_table), quality_table = load(quality_table); end
key_events = load("key_events.mat");
%% loop trhrough the tasks
for n = string(fieldnames(EEG))'
    subj = string(EEG.(n).subject);
    data_pnts = EEG.(n).pnts;
    event_cnt = length(EEG.(n).event);
    
    event_content = string({EEG.(n).event(:).type});
    key_events_exist = all(contains(key_events.(n),event_content));

    quality_table{subj,"participant_id"} = subj;
    quality_table{subj,n} = table();
    quality_table{subj,n}{1,"data_pnts"} = data_pnts;
    quality_table{subj,n}{1,"event_cnt"} = event_cnt;
    quality_table{subj,n}{1,"key_events_exist"} = key_events_exist;

end