function idx = lookup_dataset_info(STUDY, session, run, col_name, pattern, id_to_return)
%Lookup_dataset_info Checks for flags in the STUDY.datasetinfo
% This function will look up of for the patterns present in the coulmns of
% the the STUDY.datasetinfo. This is particularly useful when the STUDY is
% created from a BIDS dataset. The output is the number under
% STUDY.datasetinfo.index.
% If there are multiple column names, there will be the same number of
% cell elements in the output.
% If there are multiple patterns, the reuslts wil be the union of indices
% that mathces the pattern.
%
% (c) Seyed Yahya Shirazi, 04/2024 SCCN, INC, UCSD

%% set the variables
if ~exist("id_to_return", "var") || isempty(id_to_return), id_to_return = "index"; end
if ~exist("session", "var"), session = 1; end
if ~exist("run", "var"), run = 1; end

all_cols = string(fieldnames(STUDY.datasetinfo))';
if ~all(contains(col_name, all_cols))
    error("Column names are not available in STUDY.datasetinfo. Please check.")
end

% number of columns should be equal to the session x run
% Reason is pull datasets that have available datasetst for each session * run
if length(col_name) ~= length(session) * length(run)
    error("number of columns should be equal to the session x run")
end

%% main

% map column name to sessions and runs
for s = 1:length(session)
    for r = 1:length(run)
        mapped{(s-1)+r} = [session(s),run(r)];
    end
end
for c = 1:length(col_name)
    session_rows = [STUDY.datasetinfo(:).session] == mapped{c}(1);
    run_rows = [STUDY.datasetinfo(session_rows).run] == mapped{c}(2);
    col_data = string({STUDY.datasetinfo(run_rows).(col_name(c))});
    full_idx = {STUDY.datasetinfo(run_rows).(id_to_return)};
    idx{c} = full_idx(contains(col_data, string(pattern)));
end
