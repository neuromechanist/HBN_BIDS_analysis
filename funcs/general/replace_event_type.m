function EEG = replace_event_type(EEG, lookup_table, remove_vlaue_column)
%REPLACE_EVENT_TYPE substitute the event names (ie, types) using a lookup table
%   It so happends that simple codes are being used as event types in
%   EEG files. Such codes would be problamtic if proper descitiption is
%   not attached. A simple fix can be replacing the event codes with their
%   short descitpiotn using a lookup table.
%
%   INPUTS:
%       EEG
%           An EEGLAB structure
%       lookup_table
%           path to the lookup table TSV file
%           The first column of the table
%           contains the codes that are being used in the EEG files and the second
%           column contains the short desciption for each code.
%   
% (c) Seyed Yahya Shirazi, 04/2023 UCSD, INC, SCCN

if ~exist('remove_vlaue_column','var') || isempty(remove_vlaue_column), remove_vlaue_column = 0; end
% Load the lookup_events table
lookup_events = readtable(lookup_table, 'FileType', 'text', 'Delimiter', '\t');
lookup_events.code = string(lookup_events{:,"code"}); % Make the first column a string

% remove the value column, as it is inconsistent with the BIDS converter
if remove_vlaue_column, EEG.event = rmfield(EEG.event, 'value'); end
% Iterate through the events in EEG.event and replace the codes
for i = 1:length(EEG.event)
    code = strtrim(EEG.event(i).type); % Remove any extra spaces
    index = find(strcmp(lookup_events{:, 1}, code)); % Find the corresponding index in the lookup_events table
    if ~isempty(index)
        EEG.event(i).type = lookup_events.description{index}; % Replace the code with the descriptive name
    end
end

% Iterate through the events in EEG.urevent and replace the codes
for i = 1:length(EEG.urevent)
    code = strtrim(EEG.urevent(i).type); % Remove any extra spaces
    index = find(strcmp(lookup_events{:, 1}, code)); % Find the corresponding index in the lookup_events table
    if ~isempty(index)
        EEG.urevent(i).type = lookup_events.description{index}; % Replace the code with the descriptive name
    end
end
