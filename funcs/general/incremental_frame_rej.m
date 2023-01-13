function [ICA_STRUCT] = incremental_frame_rej(EEG, ICA_STRUCT, iqr_thres, duration, spacing)

if nargin ~= 5
    error("you need to provide all inputs for this function")
end

%% calcuating iqr

[~, ~, ~, ~, mean_norm_power] = ...
    eeg_badframes(EEG,5); % iqr used here is arbitrary and not uses in analysis

for i = 1:length(iqr_thres)
    FR(i).bad_frames = find(mean_norm_power > iqr_thres(i));
    FR(i).frame_type = ones(1,EEG.pnts);
    FR(i).frame_type(FR(i).bad_frames) = 0; % rejected frames have "0" flag
end

%% update frames with duration and spacing

for i = 1:length(iqr_thres)
FR(i).bad_frame_border_dur = duration;
FR(i).diff_frame_type = diff(FR(i).frame_type);
tmp_idx = find(FR(i).diff_frame_type == -1);
for j = 1:length(tmp_idx)
    if tmp_idx(j)-FR(i).bad_frame_border_dur+1 < 1
        FR(i).frame_type(1:tmp_idx(j)) = 0;
    else
        FR(i).frame_type(tmp_idx(j)-FR(i).bad_frame_border_dur+1:tmp_idx(j)) = 0;
    end
end
tmp_idx = find(FR(i).diff_frame_type == 1);
for j = 1:length(tmp_idx)
    FR(i).frame_type(tmp_idx(j):tmp_idx(j)+FR(i).bad_frame_border_dur) = 0;
end

FR(i).frame_type(EEG.pnts:end) = [];
FR(i).bad_frames = find(FR(i).frame_type == 0);

% if bad frames are closer than XXX time points then fill in the spaces
% with more bad frames
FR(i).min_bad_frame_spacing = spacing;
FR(i).bad_frame_spacing = diff(FR(i).bad_frames);
tmp_idx = find(FR(i).bad_frame_spacing < FR(i).min_bad_frame_spacing ...
    & FR(i).bad_frame_spacing > 1);
for j = 1:length(tmp_idx)
    FR(i).frame_type(FR(i).bad_frames(tmp_idx(j))+1:FR(i).bad_frames(tmp_idx(j)+1)-1) = 0;
end
FR(i).bad_frames = find(FR(i).frame_type == 0);
disp([num2str(length(FR(i).bad_frames)/EEG.pnts*100) ' percent of frames are bad for incr. ' num2str(i)]);
end
%% creating events and other ICA_STRUCT fields
for i = 1:length(iqr_thres)
%create bad frame events
disp('Creating bad frame events...');
dur = 1; %duration counter
curr_num_marked = 0;


n = 1;
FR(i).bad_frame_event(n).type = 'bad frame';
FR(i).bad_frame_event(n).latency = FR(i).bad_frames(1);
FR(i).bad_frame_event(n).duration = [];
FR(i).bad_frame_event(n).urevent = 1;
for j = 2:length(FR(i).bad_frames)
    if FR(i).bad_frames(j) == FR(i).bad_frames(j-1)+1
        dur = dur + 1;
    else
        %apply duration to previous event
        FR(i).bad_frame_event(n).duration = dur;
        curr_num_marked = curr_num_marked + FR(i).bad_frame_event(n).duration;
        %start new event
        n = n + 1;
        FR(i).bad_frame_event(n).type = 'bad frame';
        FR(i).bad_frame_event(n).latency = FR(i).bad_frames(j);
        FR(i).bad_frame_event(n).urevent = n;
        FR(i).bad_frame_event(n).duration = [];
        %reset duration counter
        dur = 1;
    end
end
%fill in the duration for the last event
FR(i).bad_frame_event(n).duration = dur;
curr_num_marked = curr_num_marked + FR(i).bad_frame_event(n).duration;

good_frames = EEG.pnts - curr_num_marked;
k = calc_k(good_frames,EEG.nbchan);
disp(['k value for increment No ' num2str(i) ' is ' num2str(k)])
end
%% modify ICA_STRUCT
for i = 1:length(iqr_thres)
FR(i).method = 'eeg_badframes mean thres';
FR(i).all_bad_frames = [];
ICA_STRUCT(i).frame_rej_method = {[FR(i).method ': ' int2str(iqr_thres(i))]};
ICA_STRUCT(i).min_bad_frame_spacing = FR(i).min_bad_frame_spacing;
ICA_STRUCT(i).bad_frame_border_dur = FR(i).bad_frame_border_dur;
FR(i).all_bad_frames = [FR(i).all_bad_frames FR(i).bad_frames];
ICA_STRUCT(i).percent_frames_bad = length(FR(i).bad_frames)/EEG.pnts*100;

FR(i).all_bad_frames = unique(FR(i).all_bad_frames);
ICA_STRUCT(i).rej_frame_idx = FR(i).all_bad_frames;
ICA_STRUCT(i).n_frames_for_ica = (length(ICA_STRUCT(i).chan_rej_frames_used) - length(ICA_STRUCT(i).rej_frame_idx));
ICA_STRUCT(i).k = ICA_STRUCT(i).n_frames_for_ica/length(ICA_STRUCT(i).good_chans)^2;
end
