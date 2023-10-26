function pInfo = rawFile_quality_pInfo(pInfo, quality_table)
%RAWFILE_QUALITY_PINFO Sumariuze quality metrics into a handful of flags.
%   Based on the QUALITY_TABLE, we can prvide a seires of flags to guide
%   the user about the data. This can be much simppler than the legnth of
%   the datafile or number of events.
%   The flags are:
%       Available: Data passes all qwuality checks and is available to
%       load.
%       Caution: Data file is available, but it fails at least one quality
%       check. Further look is recommended.
%       Unavailable: The data file is not available. This inculdes not
%       being able to read the data file or if the data file is not present
%       at all.
%
% (c) Seyed Yahya Shirazi, 10/2023 SCCN, INC, UCSD

%% main
qt_subjs = string(quality_table.Properties.RowNames)';
pInfo_subjs = string(pInfo(2:end,1))';
pInfo_cols = string(pInfo(1,:));
qchecks = ["data_pnts", "event_cnt", "key_event_exist", "quality_checks"];

% This should not happed, but we need to first check if there is any
% heterogenity inthe two subject lists
unique_subjs = setxor(qt_subjs, pInfo_subjs);
if ~isempty(unique_subjs), error("Unique subjects in the list, resolve the issue to proceed"); end

tasks = string(quality_table.Properties.VariableNames);
tasks(tasks == "participant_id") = [];  % this is not a task
for t = tasks
    outlier_indices = [];
    qtable = quality_table.(t);
    
    qcheck.data_pnts = find(isoutlier(qtable.data_pnts, "median", "ThresholdFactor" ,5));
    qcheck.event_cnt = find(isoutlier(qtable.event_cnt, "median", "ThresholdFactor" ,5));
    qcheck.key_event_exist = find(qtable.key_events_exist == false);
    qcheck.quality_checks = find(qtable.quality_checks~="n/a");

    for q = qchecks
        outlier_indices = [outlier_indices, qcheck.(q)']; %#ok<AGROW>
    end
    outlier_indices = unique(outlier_indices);
    outlier_subjs = qt_subjs(outlier_indices);
 
    % While the task and subjects orders should be the same for pInfo and
    % quality_table, I still make the assumption that they might chnage,
    % and we should search for both.
    task_id = find(t==pInfo_cols);
    for s = qt_subjs
        subj_id = find(s==pInfo_subjs) + 1;
        if strcmp(pInfo{subj_id, task_id},'0')
             pInfo{subj_id, task_id} = 'unavailable';
        elseif contains(s, outlier_subjs)             
            pInfo{subj_id, task_id} = 'caution'; 
        else
            pInfo{subj_id, task_id} = 'available';
        end
    end
end
