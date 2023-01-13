function cls = pickSingleSubjInCluster(cls, clsRange, outlier)
% Should a cluster contains more than one component fform a subject, we'd
% like to only keep the one with the highest variance, which by the default
% setting of AMICA is the one with smaller IC number :O
% The cluster structure has three fields that contain dipoles from
% individuals. 1- cluster.sets, 2- cluster.comps, & 3-
% cluster.preclust.preclustdata.
% We can determine multiple dipoles from the same subject in a cluster wuth
% the cluster.sets and should just remove them accordingly from the other
% two structures.
%
% Created by Seyed Yahya Shirazi, 11/1/19 UCF, inspired by Steve Peterson's
% connectivity code.
%% determine if there is multiple dipoles from the same subject
for i = clsRange
   for j = 1:length(cls(i).comps)
       for k = 1:length(cls(i).comps)
           multi_dipole.("c" + string(i))(j,k) = isequal(cls(i).sets(:,j),cls(i).sets(:,k));
       end
   end    
end

% now we should determine which dipoles are from one subject
subj_dipoles = struct();
for i = clsRange
    excluded_dipole = [];
    s = 1; % subject 1, which is arbitrary/internal to each cluster
   for j = 1:length(cls(i).comps)
      same_subj_dip  = find(multi_dipole.("c" + string(i))(j,:));
      if ~ismember(same_subj_dip(1),excluded_dipole)
          subj_dipoles(i).("s"+string(s)) = same_subj_dip;
          s = s + 1;
          excluded_dipole = sort(unique([excluded_dipole same_subj_dip]));
      end
   end    
end

%% exclude dipoles and move them to the outlier cluster
for i = clsRange
    dip2remove = [];
    for s = 1:length(fieldnames(subj_dipoles))
        if length(subj_dipoles(i).("s"+string(s))) > 1
            cls(outlier).sets = [cls(outlier).sets ...
                cls(i).sets(:,subj_dipoles(i).("s"+string(s))(2:end))];
            cls(outlier).comps = [cls(outlier).comps ...
                cls(i).comps(subj_dipoles(i).("s"+string(s))(2:end))];
            cls(outlier).preclust.preclustdata = [ cls(outlier).preclust.preclustdata; ...
                cls(i).preclust.preclustdata(subj_dipoles(i).("s"+string(s))(2:end),:)];
            % now let's remove multiple dipoles from the clusters
            dip2remove = sort(unique([dip2remove subj_dipoles(i).("s"+string(s))(2:end)]));
        end
    end
    cls(i).sets(:,dip2remove) = [];
    cls(i).comps(dip2remove) = [];
    cls(i).preclust.preclustdata(dip2remove,:) = [];
end