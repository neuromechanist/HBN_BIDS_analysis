function destination = copy_clusters_to_study(source, destination)
% In some situations, there might be a need to transfer clusters from one
% STUDY to another. While this transfer might work as easy as a simple copy
% and paste of STUDY.cluster if the individual set-files for the STUDY are
% the same, i.e.: the same conditions and sessions, but if the underlying
% setfiles are modified, for example because of a change in the condtions or
% epoch sections, without any changes to the dipole locations, then this
% transfer is not easy. The reason is STUDY.cluster saves each componenet
% relative to the underlying individual datasets and if the order or number
% of tese datasets change, the STUDY would not functin properly.
% In this function, I try to copy the clusters form source STUDY to a 
% destination STUDY with preserving the orders of the datasets of the
% destination. You might find this function useless, but when you need it,
% you will appreciatehow much it can save your time. Make sure that you
% have the same dipoles for every person and obviously the same subject set
% and order becase this function is not intended to deal with these
% differences.
%
% INPUTS:
%       source: has clusters that are determined before. By defaults, the
%       parent cluster will be ignored in this function.
%
%       destnation: I assume that it is not preclustered. Actually I will
%       delete any other clsuters other than "parentcluster" right of the
%       bat to make sure that the output is always consistent.
% © Seyed Yahya Shirazi, April 2020, UCF

%% initialize
if ~exist('source','var') || isempty(source)
    error('destination cluster should include the parent cluster of your study');
end
if ~exist('destination','var') || isempty(destination)
    error('destination cluster should include the parent cluster of your study');
end
% delete the destnation clusters except for the parentcluster, which is the
% first row
if length(destination) > 1
    warning('deleting the clusters in the desitnation, only parent cluster will remain intact.')
    destination(2:end) = [];    
end

%% create inde of the componenets in the source and desitnation parent cluster.
% each col in the cluster.sets represent a source form a subject. Whent the
% source number in the first row (or any other row) changes, it means that
% the source is from another person. So we can identify the subjects with
% that metric. ou can look up this info from STUDY.datasetinfo, but since I
% dont want to load two stdies for this part, I will infer this infoform
% the cluster information. The underlying assumption is that the number of
% sources are the sme between the two studies.
if length(source(1).comps) ~= length(destination(1).comps)
   error('source and destination clsuters do not have the same number of componenets. Are you using the same set of dipoles for both studies?')
end 
newSubj_col = [1 find(diff(source(1).sets(1,:))~=0)+1];
% find out which sets belong to each subj in both source and destiantion.
source_sets = source(1).sets(:,newSubj_col);
destination_sets = destination(1).sets(:,newSubj_col);

% copy the rest clusters in the source to the destination, but update
% deistnation.sets
for i = 1:length(source)-1
   for k = transpose(string(fieldnames(source(i)))), destination(i).(k) = source(i).(k); end
   destination(i).sets = [];
   for j = 1:size(source(i).sets,2)
       destination(i).sets(:,j) = destination_sets(:,find(source(i).sets(1,j)==source_sets(1,:),1,'first'));    
   end 
end