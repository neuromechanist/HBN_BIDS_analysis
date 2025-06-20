function augmented_list = augment_participant_list_r12(participant_list, eeg_content)
%AUGMENT_PARTICIPANT_LIST_R12 adds dataset availability to R12 participants list
%   This function creates a participants table with task availability for R12 data.
%   It works with simplified participant list (only IDs) and new EEG content format.
%   For the task details see: dx.doi.org/10.1038/sdata.2017.181
%   This function requires two inputs:
%       participant_list: path to the r12_participants.tsv (only participant IDs)
%       eeg_content: path to the eeg_content_r12.txt created by looking
%       into the available files on AWS S3.
%
% (c) Seyed Yahya Shirazi, 01/2024 UCSD, INC, SCCN

%% EEG tasks for R12
clearvars -except participant_list eeg_content
if ~exist('participant_list','var') || isempty(participant_list), participant_list = "funcs/tsv/r12_participants.tsv"; else, participant_list = string(participant_list); end
if ~exist('eeg_content','var') || isempty(eeg_content), eeg_content = "funcs/tsv/eeg_content_r12.txt"; else, eeg_content = string(eeg_content); end

all_eeg_tasks = ["RestingState",...
                "SAIIT_2AFC_Block1", "SAIIT_2AFC_Block2", "SAIIT_2AFC_Block3", ... % Visual Perception/Decision-making Paradigm
                "SurroundSupp_Block1", "SurroundSupp_Block2", ... % Inhibition/Excitation Paradigm
                "WISC_ProcSpeed", ... % WISC-IV Symbol Search Paradigm
                "vis_learn",... % Sequence Learning Paradigm
                "Video-DM", "Video-FF", "Video-WK", "Video-TP"]; % Video tasks

%% load the files
% Read participant IDs (simple text file, one ID per line)
participant_ids = readlines(participant_list);
participant_ids = participant_ids(~ismissing(participant_ids) & strlength(participant_ids) > 0); % remove empty lines

% Read EEG content file
eeg_lines = readlines(eeg_content);
eeg_lines = eeg_lines(~ismissing(eeg_lines) & strlength(eeg_lines) > 0); % remove empty lines

%% Create the augmented table
% Initialize table with participant IDs
plist = table(participant_ids, 'VariableNames', {'participant_id'});

% Initialize task columns with 0 (no file)
for t = all_eeg_tasks
    plist{:, t} = zeros(height(plist), 1);
end

%% Process EEG content and extract file sizes
i = 1;
while i <= length(eeg_lines)
    current_line = eeg_lines(i);
    
    % Check if this line is a participant ID
    if startsWith(current_line, "NDAR")
        current_participant = current_line;
        i = i + 1;
        
        % Find this participant in our table
        pindex = find(plist.participant_id == current_participant);
        
        if ~isempty(pindex)
            % Process files for this participant
            while i <= length(eeg_lines) && ~startsWith(eeg_lines(i), "NDAR")
                file_line = eeg_lines(i);
                
                % Skip "total" lines from ls -l output
                if startsWith(file_line, "total")
                    i = i + 1;
                    continue;
                end
                
                % Parse ls -l format: permissions user group size date time filename
                if startsWith(file_line, "-rw")
                    parts = split(file_line);
                    if length(parts) >= 9
                        filesize = str2double(parts{5}); % 5th column is file size
                        filename = parts{9}; % 9th column is filename
                        
                        % Check which task this file belongs to
                        for t = all_eeg_tasks
                            if contains(filename, t) && contains(filename, ".mat")
                                plist{pindex, t} = filesize;
                                break;
                            end
                        end
                    end
                end
                i = i + 1;
            end
        else
            % Skip files for participants not in our list
            i = i + 1;
            while i <= length(eeg_lines) && ~startsWith(eeg_lines(i), "NDAR")
                i = i + 1;
            end
        end
    else
        i = i + 1;
    end
end

%% Reorder columns for consistency
column_order = ["participant_id", all_eeg_tasks];
augmented_list = plist(:, column_order);

%% Save the augmented list
writetable(augmented_list, "funcs/tsv/r12_participants_augmented_filesize.tsv", "FileType","text");

fprintf('R12 participant list augmented successfully!\n');
fprintf('Output saved to: funcs/tsv/r12_participants_augmented_filesize.tsv\n');
fprintf('Total participants: %d\n', height(augmented_list));

% Display summary of task availability (files with size > 0)
fprintf('\nTask availability summary:\n');
for t = all_eeg_tasks
    available_count = sum(augmented_list{:, t} > 0);
    total_size_gb = sum(augmented_list{:, t}) / (1024^3); % Convert bytes to GB
    fprintf('  %s: %d participants (%.1f%%) - Total size: %.2f GB\n', t, available_count, 100*available_count/height(augmented_list), total_size_gb);
end

end 