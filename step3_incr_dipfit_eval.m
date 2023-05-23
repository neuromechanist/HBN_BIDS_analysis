function step3_incr_dipfit_eval(subj, mergedSetName, recompute, platform, machine, no_process)
%STEP3_INCR_DIPFIT_EVAL Applied dipfit and evaluates incr. rej. of step2
%   Following the incremental rejection process step 2 and runnig AMICA, we
%   need to run different metrics to choose the "best" rejection increment
%   for each subject.
%
% (c) Seyed Yahya Shirazi, 01/2023 UCSD, INC, SCCN

%% initialize
clearvars -except subj mergedSetName recompute platform machine no_process
close all; clc;
fs = string(filesep)+string(filesep);

% mergedSetName can be string or a vector of strings.
if ~exist('mergedSetName','var') || isempty(mergedSetName), mergedSetName = "videoEEG"; end
if length(mergedSetName)>1
    warning("Multiple concatenated datasets provided, looping through each")
    for m = mergedSetName
        step3_incr_dipfit_eval(subj, m, recompute, platform, machine, no_process)
    end
    return;
end

if ~exist('subj','var') || isempty(subj), subj = "NDARAC853DTE"; else, subj = string(subj); end
if ~exist('recompute','var') || isempty(recompute), recompute = 1; end % function does NOT recompute the best subset by default
if ~exist('platform','var') || isempty(platform), platform = "linux"; else, platform = string(platform); end
% if the code is being accessed from Expanse
if ~exist('machine','var') || isempty(machine), machine = "expanse"; else, machine = string(machine); end
if ~exist('no_process','var') || isempty(no_process), no_process = 12; end
load_existing_iclabel = ~recompute;

ps = parallel.Settings; ps.Pool.AutoCreate = false; % prevent creating parpools automatcially
if no_process ~= 0, p = gcp("nocreate"); if isempty(p), parpool("processes", no_process); end; end

%% construct necessary paths and files & adding paths
p2l = init_paths(platform, machine, "HBN", 1, false);  % Initialize p2l and eeglab.
p2l.EEGsets = p2l.eegRepo + subj + fs + "EEG_sets" + fs; % Where .set files are saved
p2l.ICA = p2l.eegRepo + subj + fs + "ICA" + fs; % Where you want to save your ICA files
p2l.incr0 =  p2l.ICA + "incr0" + fs; % pre-process directory
p2l.compResults = p2l.incr0 + fs + "comp_results" + fs;
if ~isfolder(p2l.compResults), mkdir(p2l.compResults); end

f2l.alltasks = subj + "_" + mergedSetName + ".set"; % as an Exception, path is NOT included
f2l.icaStruct = p2l.incr0 + subj + "_" + mergedSetName + "_ICA_STRUCT_" + "incremental";
f2l.icaIncr = p2l.incr0 + subj + "_" + mergedSetName + "_ICA_INCR_" + "incremental";
f2l.elocs = p2l.codebase + "funcs" + fs + "GSN_HydroCel_129_AdjustedLabels.sfp";
f2l.HDM = p2l.eeglab + "plugins" + fs + "dipfit5.2" + fs + "standard_BEM" + fs + "standard_vol.mat";
f2l.MRI = p2l.eeglab + "plugins" + fs + "dipfit5.2" + fs + "standard_BEM" + fs + "standard_mri.mat";
f2l.chan = p2l.eeglab + "plugins" + fs + "dipfit5.2" + fs + "standard_BEM" + fs + "elec" + fs + "standard_1005.elc";
f2l.INCR_chan_frames = p2l.incr0 + subj + "_" + mergedSetName + "_ICA_INCR_incremental_all_inrements_rej_channels_frames.mat";
f2l.ICA_STRUCT = p2l.incr0 + subj + "_" + mergedSetName + "_ICA_STRUCT_rejbadchannels_diverse_incr_comps.mat";
f2l.sel_comps = p2l.incr0 + subj + "_" + mergedSetName + "_ICA_STRUCT_rejbadchannels_diverse_select_comps.mat";

addpath(genpath(p2l.codebase))

%% load EEG
% NOT REQUIRED, EEG IS LOADED IN THE NEXT SECTION.
% EEG = pop_loadset( 'filename', char(f2l.alltasks), 'filepath', char(p2l.EEGsets));
% EEG = pop_chanedit(EEG, 'load', {char(f2l.elocs),'filetype','autodetect'});
% eeglab redraw

%% assesment of the increments, method1, ruuning ICALABEL
% TLDR: The increment that reuslts in the most "brain" components likely
% has the best the rejection threshold.
    
if ~exist(f2l.ICA_STRUCT,"file") || recompute
    [ICA_STRUCT, EEG] = pick_diverse_ICA(p2l, f2l, subj, mergedSetName,load_existing_iclabel);
    save(f2l.ICA_STRUCT, "-struct", "ICA_STRUCT");
else
    ICA_STRUCT = load(f2l.ICA_STRUCT);
    selected_incr = ICA_STRUCT.most_brain_increments.selected_incr;
    EEG = pop_loadset( 'filename', char(subj + "_" + mergedSetName + "_incr_" + string(selected_incr)+".set"),...
        'filepath', char(p2l.ICA+"incr"+string(selected_incr)));
    EEG = update_EEG(EEG, ICA_STRUCT, 1, 1, 0);
end

%% update to the frame-rejected data
% NOT REQUIRED ANYMORE, AS EEG HAS REJECTED CHANS.
% create an array of rejected frames compatible w/ eeg_eegrej
% rejFrame.raw = ICA_STRUCT.rej_frame_idx; % temporary rejected frames
% rejFrame.rowStart = [1 find(diff(rejFrame.raw) > 2)+1];
% for j = 1:length(rejFrame.rowStart)-1
%     rejFrame.final(j,:) = [rejFrame.raw(rejFrame.rowStart(j)) rejFrame.raw(rejFrame.rowStart(j+1)-1)];
% end
% EEG = eeg_eegrej(EEG,rejFrame.final);

%% method 2, MIR
% TLDR, the best ICA is perfromed when the mutual information reduction
% (MIR) is maximized. Since all the ICA parameters are the same for each
% subject, except for the clenaing, then highest MIR may indicate the the
% best rejection threshold.

%% mehtod 3, Dipolarity (VAR)
% This is more or less included in method 1, with the assumption that the
% lower the VAR of the components, the higher their canche to be "brain"
% components.


%% look into ICLabel & Brodmann area assignment
% define pop_viewprops variables
typecomp = 0; % 0 for component, 1 for channel
chanorcomp = ICA_STRUCT.incr_comps; % all inBrain comps should be plotted
spec_opt = {'freqrange',[2,80]}; erp_opt = {}; % pretty self describing :D
scroll_event = 1; classifier = 'ICLabel';
pop_viewprops(EEG, typecomp, chanorcomp, spec_opt, erp_opt, scroll_event, classifier);

% save the figures containting the componenets
iclabelFigs = findobj(allchild(0), 'flat', 'Type', 'figure');
for i = 1:length(iclabelFigs) % it is not possible to save the figs in .fig format
print(iclabelFigs(i),p2l.compResults + mergedSetName + "_all_components_summary_" + string(i), '-dpng', '-r600', '-noui');
print(iclabelFigs(i),p2l.compResults + mergedSetName + "_all_components_summary_" + string(i),'-dpdf', '-vector', '-noui');
end
close(iclabelFigs)
% open each compoenet's extended viewprops and save the figure, also not in
% fig format.
for i = chanorcomp
    pop_prop_extended(EEG, typecomp, i, NaN, spec_opt, erp_opt, scroll_event, classifier)
    print(p2l.compResults + mergedSetName + "_all_components_detail_comp_" + string(i), '-dpng', '-r300', '-noui')
    print(p2l.compResults + mergedSetName + "_all_components_detail_comp_" + string(i), '-dpdf', '-vector', '-noui')
    savefig(gcf,p2l.compResults + mergedSetName + "_all_components_detail_comp_" + string(i),'compact')
    close
end
