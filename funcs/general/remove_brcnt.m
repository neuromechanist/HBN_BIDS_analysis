function EEG = remove_brcnt(EEG)
%REMOVW_BRCNT removng data corresponding to brc cnt from the start or end of dataset. 
%   Working on HBN data, it turns out the the last frame that corresposnds
%   to the brc_cnt event is not a continuation of the data, therefore the
%   making continuous function such as FIR filters may fail.
%   The workaround is to see if the last event is a break_cnt
%   event and remove the data corresponding to that frame.
%
% (c) Seyed Yahya Shirazi, 05/2023 UCSD, INC, SCCN

%% profile urevent
event_types = string({EEG.event(:).type}); % OG HBN data does not have urevent

if any(contains(event_types,["break cnt","break_cnt"]))
    brcnt_idx = find(contains(event_types,["break cnt","break_cnt"]));
    if brcnt_idx(end) == length(event_types)
        EEG = pop_select(EEG,'rmpoint',[EEG.pnts-1 EEG.pnts]);
    end
else
    return;
end
