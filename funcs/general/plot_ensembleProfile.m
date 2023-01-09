function p = plot_ensembleProfile(ax, powerProfile,ensem_params,condName,plotVar,selectPowProf, ensemCol)
% This function plots ensemble metrics. Different metrics are in the
% "powerProfile" structure w/ field names equal to "ensem_params".
%
% INPUTS:
%       ax: the axs to plot the diagram, it can be either the figure or a
%       subplot axis.
%       poweProfile: A structure created by "freqband_powerProfile.m". By
%       defaiults it has some "individual" metrics and some "ensemble"
%       metrics. Here, we only need the "ensemble" fields. Note that the
%       structure might contain more than one row, represetnig diefferent
%       conditions. Each condition will its own ensemble line stacked
%       together. So, if there are 4 conditions, the ensemble profile will
%       have four curves (and shaded variability) stcked on top of
%       each other.
%       ensem_params: 1 x 2 vector. There might be different ensem metrics
%       you want to use, e.g. mean & std, or median & iqr. They should be
%       already available in the "powerProfile" strcuture. The first
%       element represent the field that will be plotted as main line and
%       the second element will be the shading around the line (as the
%       variability).
%
% Created by: Seyed Yahya Shirazi, 12/03/19 UCF
%% initialiaze
if ~exist("condName","var") || isempty(condName) || length(condName) ~= length(selectPowProf)
    warning("Condition names are not provided or do not have the same length as powerProfile length. Giving generic names")
    condName = [];
    for i = 1:length(powerProfile), condName = [condName "conds" + string(i)]; end 
else
    condName = string(condName);
end
if ~exist("plotVar","var") || isempty(plotVar), plotVar = 1; end % whether plot variance
if ~exist("selectPowProf","var") || isempty(selectPowProf), selectPowProf = 1:length(powerProfile); end % whether plot variance
if ~exist("ensemCol","var") || isempty(ensemCol), ensemCol = lines(length(selectPowProf)); end

%% plot
hold on
for i = selectPowProf
    p(i==selectPowProf) = plot(ax, powerProfile(i).(ensem_params(1)), "Color",ensemCol(i==selectPowProf,:),"DisplayName",condName(i==selectPowProf));
    if plotVar
        patchX = [1:length(powerProfile(i).(ensem_params(2))), fliplr(1:length(powerProfile(i).(ensem_params(2))))];
        if size(powerProfile(i).(ensem_params(2)),1) == 1 % the case for symmetric errors such as STE
            patchY = [powerProfile(i).(ensem_params(1)) + powerProfile(i).(ensem_params(2)),...
                fliplr(powerProfile(i).(ensem_params(1)) + -powerProfile(i).(ensem_params(2)))];
        elseif size(powerProfile(i).(ensem_params(2)),1) == 2 % the case of asymmetric errors such as EEGLAB CI
            patchY = [powerProfile(i).(ensem_params(2))(1,:),fliplr(powerProfile(i).(ensem_params(2))(2,:))];
        else
            error("error vales should be either single column for symmetric error bars or 2 columns for assumetric errors")
        end
        pth = patch(patchX,patchY,ensemCol(i==selectPowProf,:));
        pth.FaceAlpha = 0.25; pth.EdgeAlpha = 0.1; pth.Parent = ax; pth.DisplayName = condName(i==selectPowProf);
    end
end
