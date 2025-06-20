function p2l = init_paths(platform, subplat, project, init_eeglab, have_gui)
%INIT_PATHS Intializes the basic paths based on the platform
%
%   Based on the platform (Unix, PC) and subplatform (laptop, work, sccn,
%   expanse) the paths are initialized and EEGLAB will be called with our
%   without the GUI option.
%
%   (c) Seyed Yahya Shirazi, 01/2023, UCSD, INC, SCCN

%% initialize
if ~exist('platform','var') || isempty(platform), platform = "linux"; else, platform = string(platform); end % this is retired now 5/3/23
if ~exist('subplat','var') || isempty(subplat), subplat = "sccn"; else, subplat = string(subplat); end
if ~exist('project','var') || isempty(project), project = "HBN"; else, project = string(project); end
if ~exist('init_eeglab','var') || isempty(init_eeglab), init_eeglab = true; end
if ~exist('have_gui','var') || isempty(have_gui), have_gui = true; end

%% Set up the paths
if project == "HBN"
   if ismac
       if subplat ~= "mini"
        p2l.raw = "/Volumes/Yahya/Datasets/HBN/EEG/";
        p2l.eegRepo = p2l.raw; % Data is saved in the same directory
       else
           p2l.raw = "/Volumes/S1/Datasets/HBN/";
           p2l.yahya = "/Volumes/S1/Datasets/tempwork/";
           p2l.eegRepo = p2l.yahya + "HBN/EEG/";
           p2l.temp = p2l.yahya + "HBN/";
       end
        p2l.eeglab = "/Users/yahya/Documents/git/eeglab/";
        p2l.codebase = "/Users/yahya/Documents/git/HBN_BIDS_analysis/";
   elseif isunix
       if subplat == "sccn", prefix = "/data/qumulo/";
       elseif subplat == "expanse", prefix = "/expanse/projects/nemar/";
       end
       p2l.raw = prefix + "child-mind-uncompressed/";  % Original data from CMI
       p2l.yahya = prefix + "yahya/";
       p2l.eegRepo = p2l.yahya + "HBN/EEG/";  % EEG data repo
       p2l.eeglab = p2l.yahya + "_git/eeglab/";
       p2l.codebase = p2l.yahya + "_git/HBN_BIDS_analysis/";
       p2l.temp = p2l.yahya + "HBN/";
   elseif ispc
        p2l.raw = "Y://child-mind-uncompressed/";
        p2l.yahya  = "Y://yahya/";
        p2l.eegRepo = p2l.yahya + "HBN/EEG/";
        p2l.eeglab = "C://_git/eeglab_dev/";
        p2l.codebase = "C://_git/HBN_BIDS_analysis/";
        p2l.temp = p2l.yahya + "HBN/";
   else
       error("unknown platform, please take a look")
   end
end

addpath(genpath(p2l.codebase))
%% Start eeglab
if init_eeglab
    if subplat == "sccn", rmpath('/data/common/matlab/eeglab'); end
    addpath(p2l.eeglab)
    if have_gui
        if ~exist("pop_multifit.m","file"), eeglab; close; end 
    else
        eeglab nogui
    end
end