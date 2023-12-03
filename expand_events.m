function EEG = expand_events(EEG, stim_file, stim_column, resample_beyond_5p)
%EXPAND_EVENTS Expands EEG.event structure with contencts of the stim_file
%   With complex electrophys tasks such as watching a movie, the task events could
%   be very long and repetitive across subjects. Instead, we can put the
%   events in a separate STIM_FILE and expand EEGLAB's EEG.event strucutre
%   only for processing. This feature will also help to plugin alternative
%   events, if a researcher comes with their own event markers and
%   annotation for the same stimulation.
%
%   INPUTS:
%       EEG: EEGLAB's EEG structure
%       STIM_FILE: The path to the stimulation file needed for EEG.event
%       expansion.
%       STIM_COLUMN: The column that should be used form the stim file to
%       expand the EEG.event. default is "VALUE".
%       RESAMPLE_BEYOND_5p: In case there is discrepancy between the
%       key_point times, should the STIM_FILE be resampled beyon 5% of it's
%       length. If the difference is <5%, the resmapling will be
%       performed. Default is 0.
%
%   OUTPUTS:
%       EEG: EEGLAB's EEG strucutre with the expanded EEG.event.
%
% (c) Seyed Yahya Shirazi, 12/2023 SCCN, INC, UCSD

%% Inititialize
if ~exist('EEG','var') || isempty(EEG) || ~isstruct(EEG), error("No EEG strucutre is detected!"); end
if ~exist('stim_file','var') || isempty(stim_file)
    warning("No explicit STIM_FILE provided, will try to get it from BIDS stim directory");
    stim_file = []; % not yet implemented
end
if ~exist('stim_column','var') || isempty(stim_column)
    warning("No STIM_COLUMN is provided, will use the VALUE column of the STIM_FILE by default")
    stim_column = "value";
end
if ~exist('resample_beyond_5p','var') || isempty(resample_beyond_5p), resample_beyond_5p = 0; end

required_columns = ["onset", "duration"];

%% load and extract STIM-FILE events
opts = detectImportOptions(stim_file, "FileType", "text"); 
opts = setvartype(opts, 'string'); % crtitical to import everything as string/char
stim_table = readtable(stim_file, opts);

% check if the required columns and stim_colums are presents
if ~all(contains(required_columns,stim_table.Properties.VariableNames))
    error("required columns (i.e., ONSET and DURATION) are not in the stim file.")
end
if ~all(contains(stim_column,stim_table.Properties.VariableNames))
    error("The stim_columns provided as an input is not included in the stim file.")
end

% convert onset and duration to double entities
stim_table = convertvars(stim_table, required_columns, "double");
