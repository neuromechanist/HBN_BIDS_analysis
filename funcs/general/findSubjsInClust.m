function subjInClust = findSubjsInClust(STUDY, clustRow)
% Find the subject names that contribute in the specific cluster.
% © Created by Seyed Yahya Shirazi, 5/28/2020 UCF
%% a few constants
if length(clustRow) > 1, error("This function only accepts one cluster at a time."); end
subjInClust = [];
numOfConds = size(STUDY.cluster(clustRow).sets,1);
subjs = unique(string(vertcat(STUDY.datasetinfo(:).subject))'); % This is also in the order of the datasetinfo.index.
% Assuming that everybody have the same number of conditions
totalCondNum = length(subjs) * numOfConds; %#ok<NASGU>

%% now find the subjects in the cluster
for i = 1:size(STUDY.cluster(clustRow).sets,2)
    s = ceil(STUDY.cluster(clustRow).sets(1,i)/numOfConds);
    subjInClust = [subjInClust subjs(s)];    
end
