function [STUDY_out, ALLEEG] = add_comp_to_study(STUDY, STUDY_out, ALLEEG, s, all_comps)
% This function updates the study datasets with selected components
%
%
% Creared by Seyed yahya Shirazi, refactored from run10. 11/14/19 UCF

for i = 1:length(STUDY.datasetinfo)
    if isempty(STUDY_out), STUDY_in = STUDY; else, STUDY_in = STUDY_out; end
    if strcmp(STUDY.datasetinfo(i).subject,s) % this is required to edit only the relevant datasets.
        [STUDY_out, ALLEEG] = std_editset( STUDY_in, ALLEEG, 'commands',...
            {{'index' STUDY.datasetinfo(i).index 'comps' all_comps } },'updatedat','off' );
    end
end
