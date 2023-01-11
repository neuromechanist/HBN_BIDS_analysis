function p2l = init_paths(platform, subplat, project, init_eeglab, have_gui)
%INIT_PATHS Intializes the basic paths based on the platform
%
%   Based on the platform (Unix, PC) and subplatform (laptop, work, sccn,
%   expanse) the paths are initialized and EEGLAB will be called with our
%   without the GUI option.
%
%   (c) Seyed Yahya Shirazi, 01/2023, UCSD, INC, SCCN

%% initialize
if ~exist('platform','var') || isempty(platform), platform = "unix"; else, platform = string(platform); end
if ~exist('subplat','var') || isempty(subplat), subplat = "sccn"; else, subplat = string(subplat); end
if ~exist('project','var') || isempty(project), project = "HBN"; else, project = string(project); end
if ~exist('init_eeglab','var') || isempty(init_eeglab), init_eeglab = true; end
if ~exist('have_gui','var') || isempty(have_gui), have_gui = true; end

%% Set up the paths
if project == "HBN"
   if subplat == "sccn", prefix = "/data/qumulo/";
   elseif subplat == "expanse", prefix = "/expanse/projects/nemar/";
   end
   p2l.raw = prefix + "child-mind-uncompressed/";  % Original data from CMI
   p2l.eegRepo = prefix + "yahya/HBN/EEG/";  % EEG data repo
   p2l.eeglab = prefix + "yahya/_git/eeglab_dev/";    
end


%% Start eeglab
if init_eeglab
    if subplat == "sccn", rmpath('/data/common/matlab/eeglab'); end
    addpath(p2l.eeglab)
    if have_gui
        if ~exist("pop_multifit.m","file"), eeglab; close; clear("EEG"); end 
    else
        eeglab nogui
        clear EEG
    end
end