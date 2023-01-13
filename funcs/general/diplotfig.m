function fig = diplotfig(STUDY,ALLEEG,clusters_to_plot, colors2use, centProjLine, varargin)
% This function plots detailed locations of the selected dipoles and the
% centroids. Four plots will be plotted: 1- individual cluster plots with a
% large centroid, 2- Combine (aka together) plots containing all clusters
% and their centroids, 3- Centroid-free dipole clusters all together,
% and 4- Centroids only location.
%
% Inputs:
%       STUDY & ALLEEG: typical study and alleeg struxtures of eeglab that
%       conttain clsuter information.
%       clusters_to_plot: the cluster numbers matching the row number in
%       STUDY.cluster
%       color2use: cell array of the colors to be used for each cluster.
%       Each cell array should contain a triplet color for representing the
%       color to beused.
%       centProjLine: whehter to plot projection lines for the centroid
%       varargin: any parameter to be used in dipplot.
%
%   Refactored, celaned and added documentation by: Seyed Yahya Shirazi,
%   12/9/19, UCF from an HNL fnction with the same name.
%
%% initialize
if ~exist("centProjLine","var") || isempty(centProjLine), centProjLine = 0; end
compsall=[];
centsall=[];
sources = [];
dipsizes = [];

%% plot individual clusters and centroids
ct = 1; k1=1;
for i=1:length(clusters_to_plot)
    for j=1:length(STUDY.cluster(clusters_to_plot(i)).comps)
        abset   = STUDY.datasetinfo(STUDY.cluster(clusters_to_plot(i)).sets(1,j)).index;
        if ~isfield(ALLEEG(abset), 'dipfit')
            warndlg2(['No dipole information available in dataset ' ALLEEG(abset).filename ' , abort plotting'], 'Aborting plot dipoles');
            return;
        end
        comp = STUDY.cluster(clusters_to_plot(i)).comps(j);
        cluster_dip_models(1,j).posxyz = ALLEEG(abset).dipfit.model(comp).posxyz;
        cluster_dip_models(1,j).momxyz = ALLEEG(abset).dipfit.model(comp).momxyz;
        cluster_dip_models(1,j).rv = ALLEEG(abset).dipfit.model(comp).rv;
        
        colorsall{ct} = colors2use{i};
        colorsc_1{k1} = colors2use{i};
        colors1cls{j} = colors2use{i};

        ct= ct+1; k1=k1+1;
    end
    compsall=[compsall,cluster_dip_models(1,:)];
    centsall = [centsall, computecentroid(cluster_dip_models)];
    sources = [sources, cluster_dip_models(1,:), computecentroid(cluster_dip_models)];
    dipsizes = [dipsizes 25*ones(size(1,length(cluster_dip_models(1,:)))) 20];
    %     centsall=[centsall,sources(i)];
    dipOptions = {'spheres','on','dipolelength',0,'dipolesize',[20*ones(1,length(cluster_dip_models(1,:))) 40],...
        'mri',ALLEEG(1).dipfit.mrifile,'meshdata',ALLEEG(1).dipfit.hdmfile,...
        'coordformat',ALLEEG(1).dipfit.coordformat,'color',colors1cls};
    if ~isempty(varargin), dipOptions = [dipOptions varargin]; end
    if centProjLine, projLine = [zeros(1,length(cluster_dip_models(1,:))) 1]; dipOptions = [dipOptions {'projlines',projLine}]; end
    dipplot([cluster_dip_models(1,:), computecentroid(cluster_dip_models)],dipOptions{:});
    set(findobj('facealpha',0.6),'facelighting','phong');
%     drawnow;
    fig.("c"+string(i)+"_dipLoc") = get(groot,'CurrentFigure');
    clear cluster_dip_models colors1cls
end

%% plot "togther" plots
% colors2use
for i=1:length(clusters_to_plot)
    colorsall{ct-1+i} = colors2use{i};
end

% clusters and centroids together.
dipOptions = {'spheres','on','dipolelength',0,'dipolesize',[20*ones(size(compsall)) 40*ones(size(centsall))],...
    'mri',ALLEEG(1).dipfit.mrifile,'meshdata',ALLEEG(1).dipfit.hdmfile,'coordformat',ALLEEG(1).dipfit.coordformat,...
    'color',colorsall};
if ~isempty(varargin), dipOptions = [dipOptions varargin]; end
if centProjLine, projLine = [zeros(1,length(compsall)) ones(1,length(centsall))]; dipOptions = [dipOptions {'projlines',projLine}]; end
dipplot([compsall centsall],dipOptions{:});
set(findobj('tag','img'), 'facealpha', 0.6);
set(findobj('facealpha',1),'facelighting','phong');
% drawnow;
fig.dipsNcents = get(groot,'CurrentFigure');

% clusters together
dipOptions = {'spheres','on','dipolelength',0,'dipolesize',20,'mri',ALLEEG(1).dipfit.mrifile,...
    'meshdata',ALLEEG(1).dipfit.hdmfile,'coordformat',ALLEEG(1).dipfit.coordformat,'color',colorsc_1};
if ~isempty(varargin), dipOptions = [dipOptions varargin]; end
dipplot(compsall, dipOptions{:});
set(findobj('tag','img'), 'facealpha', 0.6);
set(findobj('facealpha',1),'facelighting','phong');
% drawnow;
fig.dips = get(groot,'CurrentFigure');

% centroids together
dipOptions = {'spheres','on','dipolelength',0,'dipolesize',40,'mri',ALLEEG(1).dipfit.mrifile,...
    'meshdata',ALLEEG(1).dipfit.hdmfile,'coordformat',ALLEEG(1).dipfit.coordformat,'color',colors2use};
if ~isempty(varargin), dipOptions = [dipOptions varargin]; end
if centProjLine, dipOptions = [dipOptions {'projlines','on'}]; end
dipplot(centsall,dipOptions{:});
set(findobj('tag','img'), 'facealpha', 0.6);
set(findobj('facealpha',1),'facelighting','phong');
% drawnow;
fig.cents = get(groot,'CurrentFigure');

end % end of the main function

%% auxiliary functions
function dipole = computecentroid(alldipoles)

len = length(alldipoles);
dipole.posxyz = [ 0 0 0 ];
dipole.momxyz = [ 0 0 0 ];
dipole.rv = 0;
count = 0;
warningon = 1;
for k = 1:len
    if size(alldipoles(k).posxyz,1) == 2
        if all(alldipoles(k).posxyz(2,:) == [ 0 0 0 ])
            alldipoles(k).posxyz(2,:) = [];
            alldipoles(k).momxyz(2,:) = [];
        end
    end
    if ~isempty(alldipoles(k).posxyz)
        dipole.posxyz = dipole.posxyz + mean(alldipoles(k).posxyz,1);
        dipole.momxyz = dipole.momxyz + mean(alldipoles(k).momxyz,1);
        dipole.rv     = dipole.rv     + alldipoles(k).rv;
        count = count+1;
    elseif warningon
        disp('Some components do not have dipole information');
        warningon = 0;
    end
end
dipole.posxyz = dipole.posxyz/count;
dipole.momxyz = dipole.momxyz/count;
dipole.rv     = dipole.rv/count;
if isfield(alldipoles, 'maxr')
    dipole.maxr = alldipoles(1).max_r;
end
end % end of the function
