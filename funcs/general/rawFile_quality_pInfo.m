function [pInfo, rm_id] = rawFile_quality_pInfo(pInfo, quality_table, target_tasks, override_pInfo, save_path)
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
%   INPUTS:
%       pInfo: The standrard participant information requireed cell array
%       required for the BIDS_EXPORT function. This array is created using
%       the CONVERT_HBN2BIDS function.
%       quality_table: The table that includes a summary of the quality
%       checks performed on the dataset. Currently the data points, number
%       of events and key events are hardcoded in the table (from
%       RUN_QUALITY_METRICS) and here. For additional checks, you can use
%       EEG.etc.quality_checks.
%       save_path: If present, the quality table for each task will be
%       savewd in the path as a TSV file.
%
% (c) Seyed Yahya Shirazi, 10/2023 SCCN, INC, UCSD

%% main
qt_subjs = string(quality_table.Properties.RowNames)';
pInfo_subjs = string(pInfo(2:end,1))';
pInfo_cols = string(pInfo(1,:));
qchecks = ["data_pnts", "event_cnt", "key_event_exist", "quality_checks"];
rm_id = [];

% check if seqlearning is a column
if any(contains(quality_table.Properties.VariableNames, "seqLearning"))
    quality_table(:,"seqLearning") = [];  % remove sequence learning, as it is broken up to two tasks.
end

% This should not happen, but we need to first check if there is any
% heterogenity inthe two subject lists
unique_subjs = setxor(qt_subjs, pInfo_subjs);

if ~isempty(unique_subjs)
    if ~override_pInfo
        error("Unique subjects in the list, resolve the issue to proceed");
    else
        if contains(unique_subjs, pInfo_subjs)
            for u = unique_subjs
                rm_id = [rm_id, find(u == pInfo_subjs)];
                pInfo(find(u == pInfo_subjs)+1,:) = [];
                pInfo_subjs = string(pInfo(2:end,1))';
                warning("pInfo has more subjects, but you chose to continue, removing the subject from dataset");        
            end
        else
            for u = unique_subjs
                quality_table(u,:) = [];
                qt_subjs = string(quality_table.Properties.RowNames)';
                warning("quality_table has extra subjects, but you  chose to continue, removing the subject from table")
            end
        end
    end
end

tasks = string(quality_table.Properties.VariableNames);
tasks(tasks == "participant_id") = [];  % this is not a task
% check for the case that no subject had one of the tasks
% for that, check if the all target_tasks are accounted for in tasks
missing_tasks = target_tasks(~contains(target_tasks, tasks));

for t = tasks
    outlier_indices = [];
    qtable = quality_table.(t);
    qtable.Properties.RowNames = quality_table.Properties.RowNames;
    % treat any missing values as n/a in quality_checks
    qtable{ismissing(qtable(:, "quality_checks")), "quality_checks"} = "n/a";
    % treat zeros in numeric columns as NaN
    col_names = string(qtable.Properties.VariableNames);
    col_names(col_names=="quality_checks") =[]; col_names(col_names=="key_events_exist") =[];
    for c = col_names, qtable{qtable{:, c}==0, c} = NaN; end
    % write the table
    if exist("save_path","var")
        writetable(qtable, save_path + t + "_quality_table.tsv", "FileType", "text", "WriteRowNames",true)
    end

    outliers = find(isoutlier(qtable.data_pnts, "median", "ThresholdFactor" ,5));
    poutliers = find_outlier_by_percent(qtable.data_pnts, 0.2);
    qcheck.data_pnts = intersect(outliers,poutliers);

    outliers = find(isoutlier(qtable.event_cnt, "median", "ThresholdFactor" ,5));
    poutliers = find_outlier_by_percent(qtable.event_cnt, 0.2);
    qcheck.event_cnt = intersect(outliers,poutliers);
    
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

% handle the missing data
for m = missing_tasks
    pInfo(2:end , m==pInfo_cols) = {'unavailable'}; 
end

function idx = find_outlier_by_percent(values, percentage)

mid = median(values);

bigger = find(values > (mid * (1 + percentage)));
smaller = find(values < (mid * (1 - percentage)));

idx = union(bigger, smaller);