studyFile = "PS_young_fraction1_17subjs_select_comp.study";
studyPath = "Z:\BRaIN\eeg\PS\EEG\STUDIES\";

%% load the study
load(studyPath+studyFile,"-mat");

%% replace the file path
% You can look into the change you want to make. For my current
% implementation, I only need to change the drive
for i = 1:length(STUDY.datasetinfo)
    [r,rr] = strtok(STUDY.datasetinfo(i).filepath,"D:\");
    STUDY.datasetinfo(i).filepath = ['Z:\', r, rr];
end

%% save the study
save(studyPath+studyFile,"STUDY","-mat");