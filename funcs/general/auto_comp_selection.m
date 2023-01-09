function [all_comps, ICA_STRUCT] = auto_comp_selection(ICA_STRUCT, p2l)
% this functions chooses brain, muscle and eye componnents for each person
% based on the ICLABEL resuslts. ICLABEL resuslts were privously recorded
% inside ICA_STRUCT in run4. You can also create a recycled structure,
% contaning compnents you want to include manually.
%
% Create by Seyed Yahha SHirazi by refactoring a section of run8, 11/14/19 UCF

%% initialize
fs = string(filesep);
ICA_STRUCT.good_comps.eye = []; ICA_STRUCT.good_comps.muscle = []; ICA_STRUCT.good_comps.recycled = [];

% find each component's assignment
for i = 1:length(ICA_STRUCT.classification.ICLabel.classifications)
    if max(ICA_STRUCT.classification.ICLabel.classifications(i,:)) == ICA_STRUCT.classification.ICLabel.classifications(i,3)
        ICA_STRUCT.good_comps.eye = [ICA_STRUCT.good_comps.eye i];
    elseif max(ICA_STRUCT.classification.ICLabel.classifications(i,:)) == ICA_STRUCT.classification.ICLabel.classifications(i,2)
        ICA_STRUCT.good_comps.muscle = [ICA_STRUCT.good_comps.muscle i];
    end
end

%% include manual componenets, if there is one
% If you went over the comps and decided to re-include some that were
% automatically excluded, just dave it in reycle_comps structre with the
% subject as the field name.
if exist(p2l.eegRepo + "STUDIES" + fs + "recycled_comps.mat","file")
    load(p2l.eegRepo + "STUDIES" + fs + "recycled_comps.mat","recycled_comps");
    if isfield(recycled_comps,subj)
        ICA_STRUCT.good_comps.recycled = recycled_comps.(subj);
    end
end

%% rebuild ICA_STRUCT and all_comps
ICA_STRUCT.good_comps.brain = sort(unique([ICA_STRUCT.good_comps.all ICA_STRUCT.good_comps.recycled]));
all_comps = sort(ICA_STRUCT.incr_comps); % defined in pick_diverse_ica.m as the components that are insode the brain with low RV. Seyed, 11/20/19