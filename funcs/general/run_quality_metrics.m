function quality_table = run_quality_metrics(EEG, task, quality_table, key_events, save_table)
%RUN_QUALITY_CHECK quantifies simple quality metrics for BIDS EEG runs.
%   This function uqwanitfies simple quaLity-related metrics for the EEG
%   taski runs and saves (and append) them in a table. The quality metrics
%   include, (1) number of data points, (2) event count, (3) presence of
%   key events. The QUALITY_TABLE will be appended if it is provided.
%
% (c) Seyed Yahya Shirazi, 10/2023 SCCN, INC, UCSD

if ~exist("quality_table","var") || isempty(quality_table), quality_table = table(); end
if isstring(quality_table), quality_table = load(quality_table); end
if ~exist("task","var"), task = []; end
if ~exist("save_table","var") || isempty(save_table), save_table = true; end
if ~exist("key_events","var") || isempty(key_events)
    key_events = load("key_events.mat");
elseif isstring(key_events)
    key_events = load("key_events.mat");
end

%% main
subj = string(EEG.subject);
data_pnts = EEG.pnts;
event_cnt = length(EEG.event);

event_content = string({EEG.event(:).type});
key_events_exist = all(contains(key_events.(task), event_content));

% add quality metrics indicated in EEG.etc to the table
etc_fields = fieldnames(EEG.etc)';
if contains("quality_checks", etc_fields) && isstruct(EEG.etc.quality_checks)
    quality_checks = string(fieldnames(EEG.etc.quality_checks))';
else
    quality_checks = "n/a";
end

temp_table = table();
temp_table{subj, "participant_id"} = subj;
temp_table{subj, "data_pnts"} = data_pnts;
temp_table{subj, "event_cnt"} = event_cnt;
temp_table{subj, "key_events_exist"} = key_events_exist;

qcheck_string = [];
for q = quality_checks
    if q == "n/a"
        qcheck_string = "n/a";
        break;
    elseif isempty(EEG.etc.quality_checks.(q))
        qcheck_string = "n/a";
        break;
    else
        qcheck_string = [qcheck_string; EEG.etc.quality_checks.(q)];
    end
end
temp_table{subj, "quality_checks"} = qcheck_string;


if isempty(task)
    quality_table = [quality_table; temp_table];
else
    quality_table{subj, "participant_id"} = subj;
    temp_table.participant_id = [];
    quality_table{subj,task} = temp_table;
end

%% save the table
if save_table
    save("funcs/tsv/quality_table","quality_table");
end