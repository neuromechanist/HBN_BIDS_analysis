function BAnums = talLookup_pos(pos, confusion_sphere, max_sphere, convert_mni2tal)
%
% This funtion is originally EEGLAB.MPT.eeg_lookup_talairach, modified to
% be used in compatibitiy w/ EEGLAB, especially via dipplot, in a way that
% gving an array of n x 3 "POS" as input will give out an integer array of
% n x 1 which correspondes to the Brodmann area of the each row of the POS
%
% INPUT:
%       POS: is the posxyz form the EEGLAB dipole structure
%       confusion_sphere: is the area that the function looks for Brodmann
%       areas
%
% output:
%       BAnums: Brodmann area numbers for each row of the POS
%
% Created by: Seyed Yahya Shirazi, BRaIN Lab, UCF
% email: shirazi@ieee.org
%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
% function EEG = eeg_lookup_talairach(EEG,confusion_sphere)
%
% Look up dipole structure labels from Talairach, and add to EEGLAB dataset (in the .dipfit field)
% EEG = eeg_lookup_talairach(EEG)
%
% In:
%   EEG : EEGLAB data set with .dipfit structure
%
%   ConfusionSphere : radius of assumed sphere of confusion around dipfit locations (to arrive at 
%                     probabilities), in milimeters (default: 10)
%
% Out:
%   EEG : EEGLAB data set with associated labels
%
% Example:
%   % load data set and do a lookup
%   eeg = pop_loadset('/data/projects/RSVP/exp53/realtime/exp53_target_epochs.set')
%   labeled = eeg_lookup_talairach(eeg)
%
%   % show structure labels and associated probabilities for component/dipole #17
%   labeled.dipfit.model(17).structures
%   labeled.dipfit.model(17).probabilities
%
% TODO:
%   % Replace sphere by a Gaussian with std. dev.
%
%                                Christian Kothe, Swartz Center for Computational Neuroscience, UCSD
%                                2011-04-06
%% initialize
BA_nums = 52; %#ok<NASGU>
if ~exist('confusion_sphere','var') || isempty(confusion_sphere)
    confusion_sphere = .5; end % changed to 0.5 to better resemble Talairach Client, Seyed 11-4-19

% Whether the locations are alreay in tal coordinate or need conversion,
% default is 1, meaning that locations are in MNI coordinate and need conversion, Seyed 11-4-19
if ~exist('convert_mni2tal','var') || isempty(convert_mni2tal)
    convert_mni2tal = 1; end

% Should no Brodmann area is foound for a specific set of location, this
% function would increase the sphere that it looks for the Brodmann areas
% iteretively. "max_sphere" is the upper bound for expansion of the search
% sphere, default is 10mm. Seyed 11-18-19
if ~exist('max_sphere','var') || isempty(max_sphere)
    max_sphere = 10; end 

if ~exist('org.talairach.Database','class')
    javaaddpath(['funcs' filesep 'general' filesep 'talairach.jar']); end

db = org.talairach.Database;
db.load(['funcs' filesep 'talairach.nii']);

%% estimate Talairach assignments and the most probable Brodmann area
for k=1:size(pos,1)
    try
        if convert_mni2tal, p = mni2tal(pos(k,:)); else, p = pos(k,:); end
        labels = cellfun(@(d)char(d),cell(db.search_range(p(1),p(2),p(3),confusion_sphere)),'UniformOutput',false);
        % and compute structure probabilities within the selected volume
        [structures,x,idxs] = unique(hlp_split(sprintf('%s,',labels{:}),',')); %#ok<ASGLU>
        probabilities = mean(bsxfun(@eq,1:max(idxs),idxs));
        [probabilities,reindex] = sort(probabilities,'descend');
        structures = structures(reindex);
        mask = ~strcmp(structures,'*');
        structures = string(structures(mask));
        probabilities = probabilities(mask)*5; %#ok<NASGU> % there are 5 partitions
        BAname = structures(find(contains(structures,"Brodmann"),1,'first'));
        BAnums(k) = str2double(strtok(BAname,"Brodmann area "));
    catch
        BAnums(k) = nan;
    end
    % If there is no answer, gradually increase the confusion sphere to get an
    % answer
    if isnan(BAnums(k)) && confusion_sphere < max_sphere
        BAnums(k) = talLookup_pos(pos(k,:), confusion_sphere * 1.5);
    end
end

function res = hlp_split(str,delims)
% Split a string according to some delimiter(s).
% Result = hlp_split(String,Delimiters)
%
% In:
%   String : a string (char vector)
%
%   Delimiters : a vector of delimiter characters (includes no special support for escape sequences)
%
% Out:
%   Result : a cell array of (non-empty) non-Delimiter substrings in String
%
% Examples:
%   % split a string at colons and semicolons; returns a cell array of four parts
%   hlp_split('sdfdf:sdfsdf;sfdsf;;:sdfsdf:',':;')
% 
%                                Christian Kothe, Swartz Center for Computational Neuroscience, UCSD
%                                2010-11-05

pos = find(diff([0 ~sum(bsxfun(@eq,str(:)',delims(:)),1) 0]));
res = cell(~isempty(pos),length(pos)/2);
for k=1:length(res)
    res{k} = str(pos(k*2-1):pos(k*2)-1); end
