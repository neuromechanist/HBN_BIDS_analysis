function quality_table = run_quality_metrics(EEG, quality_table)
%RUN_QUALITY_CHECK quantifies simple quality metrics for BIDS EEG runs.
%   This function uqwanitfies simple quaLity-related metrics for the EEG
%   taski runs and saves (and append) them in a table. The quality metrics
%   include, (1) number of data points, (2) event count, (3) presence of
%   key events. The QUALITY_TABLE will be appended if it is provided.
%
% (c) Seyed Yahya Shirazi, 10/2023 SCCN, INC, UCSD

if ~exist("quality_table","var") || isempty(quality_table), quality_table = table(); end
if isstring(quality_table), quality_table = readtable(quality_table, "FileType", "text"); end