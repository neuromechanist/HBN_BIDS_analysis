function idx = lookup_dataset_info(STUDY, col_name, pattern, id_to_return)
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

all_cols = string(fieldnames(STUDY.datasetinfo))';
if ~all(contains(col_name, all_cols))
    error("Column names are not available in STUDY.datasetinfo. Please check.")
end

for c = string(col_name)
    col_data = string({STUDY.datasetinfo(:).(c)});
    full_idx = {STUDY.datasetinfo(:).(id_to_return)};
    idx{c == string(col_name)} = full_idx(contains(col_data, string(pattern)));
end
