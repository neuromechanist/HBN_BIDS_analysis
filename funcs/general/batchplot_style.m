function batchplot_style(h, param, gappts)

% BATCHPLOTSTYLE formats a batchplot, notably highlighting different phases
%   by adding "gaps."
% 
%   BATCHPLOTSTYLE(H), accepts an axes handle, H, for the batchplot. 
%   Multiple batchplots could exist in a single figure with subplots. If no
%   other input arguments are provided, then default figure parameters are
%   used (see below).
%
%   BATCHPLOTSTYLE(H, PARAM), formats batchplot with the following figure
%   parameters:
%
%       PARAM.pt = 14; % default size for text labels
%       PARAM.npt = 12; % default size for numbers on axes
%       PARAM.font = 'Arial'; % default font type
%       PARAM.linewidth = 2; % default size for linewidth
%       PARAM.linestyle = '-'; % default size for linewidth
%       PARAM.color = 'default'; % default color scheme
%       PARAM.title = ''; % specific title, if default, title = 'Batchplot'
%       PARAM.ylabel = ''; % variable name, if 'default', ylabel = 'Metric'
%       PARAM.xlabel = ''; % custom xlabel, if 'default', then xlabel
%           = 'Batch ( = [batchsize] trials)' or 'Batch' if batchsize is
%           not specified
%       PARAM.batchsize = ''; % number, not a string
%       PARAM.winwidth = 0.6; % value 0-1, equal to % of screen size
%       PARAM.winlength = 0.8; % value 0-1, equal to % of screen size
%       PARAM.phasenames = ''; % cell array with phase names. Number of
%           phasenames must equal length(GAPPTS)+1. Phase names will be
%           placed at 0.9 of the maximum magnitude y-limit of the y-axis, 
%           i.e. if data is positive, phase names will be at the top, and 
%           if data is negative, phase names will be at the bottom.
%
%   These default PARAM values just plot the data with no descriptive text
%
%   BATCHPLOTSTYLE(H, PARAM, GAPPTS) or BATCHPLOTSTYLE(H, [], GAPPTS), 
%   formats batchplot with gaps at GAPPTS and colors each section a
%   different color. GAPPTS is a vector with the last batch number of each
%   phase. Ex. if batch numbers 1-40 are for the baseline phase, 41-90 are
%   the learning phase, and 91-130 are washout, then GAPPTS = [40 90];
%
%   Written by Helen J. Huang, 23 Mar 2011 

error(nargchk(1, 3, nargin));

% default values

color2use = [0 0 0; 0 1 0; 0 0 1; 1 0 0; 1 1 0; 0 1 1];
marker2use = {'.' 'o' 'd' 'x' 's' '^' '*' '<' '>' '+'};
% line2use = {'-' ':' '--' '-.'};

if strcmp(get(h, 'Type'), 'figure'), error('Must use axes handle'); end

if nargin < 2, param = []; end

paramfields = {'pt' 'npt' 'font' 'linewidth' 'linestyle' 'color' 'title' 'ylabel' 'xlabel' 'batchsize' 'winwidth' 'winlength' 'phasenames'};
if ~isempty(param),
    fieldsin = fieldnames(param);
    if sum(~ismember(fieldsin, paramfields)) > 0  
        error('Check field names you''ve assigned in PARAM. There is an unknown field name');
    end
end

if ~isfield(param, 'pt'), param.pt = 14; end %size for text labels
if ~isfield(param, 'npt'), param.npt = 12; end %size for number labels
if ~isfield(param, 'font'), param.font = 'Arial'; end
if ~isfield(param, 'linewidth'), param.linewidth = 2; end
if ~isfield(param, 'linestyle'), param.linestyle = '-'; end
if ~isfield(param, 'color'), param.color = 'default'; end
if ~isfield(param, 'title'), param.title = 'default'; end
if ~isfield(param, 'ylabel'), param.ylabel = 'default'; end
if ~isfield(param, 'xlabel'), param.xlabel = 'default'; end
if ~isfield(param, 'batchsize'), param.batchsize = []; end
if ~isfield(param, 'winwidth'), param.winwidth = 0.6; end
if ~isfield(param, 'winlength'), param.winlength = 0.8; end
if ~isfield(param, 'phasenames'), param.phasenames = {}; end

if nargin == 3
    if ~isvector(gappts), error('gappts must be a vector'); end
    if ~isempty(param.phasenames) && length(param.phasenames) ~= length(gappts)+1,
        error('Number of phasenames and phases, as determined from length(gappts)+1, do not match');
    end
    if gappts(1) ~= 0, gappts = [0 gappts]; end
end

hf = get(h, 'Parent');
scrsz = get(0,'ScreenSize');
set(hf, 'color', 'white');
set(hf, 'position', [scrsz(3)*0.1 scrsz(4)*0.1 scrsz(3)*param.winwidth scrsz(4)*param.winlength])
figure(hf);
axis tight

hold on;

if nargin == 3
    % Get data from each patch
    clear datah
    datah = findobj(h, 'Type', 'patch');
    for hct = 1:length(datah)
        clear X Y gaps
        hp = datah(hct);
        X = get(hp, 'XData');
        max_x = max(get(gca, 'xlim'));
        if length(X) < max_x
            break
        else
            Y = get(hp, 'YData');
            if gappts(end) > X(ceil(length(X)/2)), error('gappts exceed maximum batch number'); end
            gaps = [gappts X(ceil(length(X)/2))];
            
            color2use_user = get(hp, 'facecolor');
            
            % delete existing patch and re-patch with gap
            delete(hp);
            for ct = 1:length(gaps)-1
                if ~strcmp(param.color, 'nochange')
                    patch([X(floor(gaps(ct))+1:floor(gaps(ct+1))); X(end-floor(gaps(ct+1))+1:end-floor(gaps(ct)))],...
                        [Y(floor(gaps(ct))+1:floor(gaps(ct+1))); Y(end-floor(gaps(ct+1))+1:end-floor(gaps(ct)))], ...
                        color2use((mod(ct-1,6)+1),:),...
                        'EdgeColor', color2use((mod(ct-1,6)+1),:), 'facealpha', 0.5, 'edgealpha', 0.5);
                else
                    patch([X(floor(gaps(ct))+1:floor(gaps(ct+1))); X(end-floor(gaps(ct+1))+1:end-floor(gaps(ct)))],...
                        [Y(floor(gaps(ct))+1:floor(gaps(ct+1))); Y(end-floor(gaps(ct+1))+1:end-floor(gaps(ct)))], ...
                        color2use_user, 'EdgeColor', color2use_user, 'facealpha', 0.5, 'edgealpha', 0.5);
                end
            end
        end
    end
    
    % Get data from each line
    clear datah
    datah = findobj(h, 'Type', 'line');
    for hct = 1:length(datah)
        clear X Y gaps
        hd = datah(hct);
        X = get(hd, 'XData');
        max_x = max(get(gca, 'xlim'));
        if length(X) < max_x
            break
        else
            Y = get(hd, 'YData');
%             linetype = get(hd, 'linestyle');
            
            if isnan(X), continue, end
            
            gaps = [gappts X(end)];
            color2use_user = get(hd, 'color');
            
            % delete existing line and replot with gap
            delete(hd);
            for ct = 1:length(gaps)-1
                if ~strcmp(param.color, 'nochange')
                    plot(X(floor(gaps(ct))+1:floor(gaps(ct+1))), Y(floor(gaps(ct))+1:floor(gaps(ct+1))), ...
                        'linewidth', param.linewidth, 'linestyle', param.linestyle, 'color', color2use((mod(ct-1,6)+1),:));
                else
                    plot(X(floor(gaps(ct))+1:floor(gaps(ct+1))), Y(floor(gaps(ct))+1:floor(gaps(ct+1))), ...
                        'linewidth', param.linewidth, 'linestyle', param.linestyle, 'color', color2use_user);
                end
                %[marker2use{(mod(hct-1,10)+1)} '-']
            end
        end
    end
    
    % Add labels for phases, if specified
    if ~isempty(param.phasenames)
        ylimits = ylim(h); yval = max(abs(ylimits));
        if yval == max(ylimits), ysign = 1; else ysign = -1; end
        for ct = 1:length(gaps)-1
            text(mean(X(floor(gaps(ct))+1:floor(gaps(ct+1)))), ysign*yval*0.9, param.phasenames{ct}, ...
                'FontSize', param.pt, 'HorizontalAlignment', 'center', 'color', color2use((mod(ct-1,6)+1),:));
        end
    end
end

box off
set(h, 'FontSize', param.npt);
set(h, 'FontName', param.font)
set(h, 'LineWidth', 1);
set(h, 'XColor', [0,0,0]);
set(h, 'YColor', [0,0,0]);
set(h, 'Color', [1,1,1]);

ht = get(h, 'Title');
set(ht, 'FontSize', 16);
set(ht, 'Color', [0,0,0]);
set(ht, 'FontName', param.font)
set(ht, 'FontWeight', 'bold');
if strcmp(param.title, 'default')
    if ~strcmp(param.ylabel, 'default')
        set(ht, 'String', ['Batchplot: ' param.ylabel]); 
    else
        set(ht, 'String', 'Batchplot');
    end
else
    set(ht, 'String', param.title);
end

xlab_h = get(h, 'XLabel');
set(xlab_h, 'Color', [0,0,0]); % set the label text color
set(xlab_h, 'FontSize', param.pt);
set(xlab_h, 'FontName', param.font)
if strcmp(param.xlabel, 'default')
    if ~isempty(param.batchsize)
        set(xlab_h, 'String', ['Batch (= ' num2str(param.batchsize) ' trials)']); 
    else
        set(xlab_h, 'String', 'Batch');
    end
else
    set(xlab_h, 'String', param.xlabel);
end

ylab_h = get(h, 'YLabel');
set(ylab_h, 'Color', [0,0,0]); % set the label text color
set(ylab_h, 'FontSize', param.pt);
set(ylab_h, 'FontName', param.font)
if strcmp(param.ylabel, 'default')
    set(ylab_h, 'String', 'Metric');
else
    set(ylab_h, 'String', param.ylabel);
end

% Set the line width & style
% datah = findobj(gca, 'Type', 'line');
% for hd = datah
%     set(hd, 'LineWidth', param.linewidth, 'linestyle', param.linestyle);
% end