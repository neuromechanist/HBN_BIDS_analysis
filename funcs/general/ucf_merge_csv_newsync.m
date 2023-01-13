function EEG = ucf_merge_csv_newsync(EEG,dflow_file,treadmill_file,save_gait_path,save_gait_mat,save_gait_plots)
%merge_csv.m
%
%Function to:
%   1) load csv  output files - first line with two or more comma or tab
%       separted numbers is considered the first line of data
%   2) time sync to EEG based on EEG event ('sync_rising_edge') and a
%       sync channel (square wave) in the csv data
%   3) save the csv header in eeg.etc and the csv data in eeg.other_data
%
%INPUTS
%   csv_filename: full filepath and filename of the .csv file
%   csv_sync_channel: name of the csv channel that contains 
%       the sync signal (string)
%   csv_sample_rate: sample rate of data in csv file
%   resample_threshold (optional input)
%       if the maximum offset between triggers is less than this value
%       (in seconds) then the csv data will automatically be
%       resampled to minimize this offset. If the maximum offset is greater
%       than this value than the user will be prompted what to do. 
%       (default = 0)
%   channel_label_line: (optional input) integer - the line number in the csv file
%       containing the channel labels. if empty then channels are labelled Data 1 ... Data N 

%Created by: J Gwin 2/20/2010 - modification of merge_biomech.m
%JLukos 02/07/2013 - modified for use at ARL TNB

%Modified by Hendrik Enders 09/15/2014 for NuStep Gait Events
%Modified by Helen Huang 04/02/2015 for Nustep Active, Walking project
%   changed csv_sync_channel from Sync to SYNC
%   added if then to handle different EEG_SYNC_EVENT_TYPE
%       for Nustep = 65535


%%you need to handle the fact sync events with latency of 1 are more than
%%likely wrong and are the result of starting the collection when the sync
%%signal is high

EEG_SYNC_EVENT_TYPE = 65535; %32774; %65535; %32776 rising !!check to make sure the type is correct!
for i=1:length(EEG.event)
    if EEG.event(i).type ==EEG_SYNC_EVENT_TYPE
        if EEG.event(i).latency==1
            EEG.event(i).type='INCORRECT SYNC EVENT';
        end
    end
end
%
csv_sync_channel='SYNC';
csv_sample_rate=1000;%for InclineWalking data
channel_label_line=4; %for InclineWalking data - check your own CSV file, may change
resample_threshold = 0.01;


%load csv data
fid = fopen(csv_filename);
line = fgetl(fid);
n = 0;
while length(str2num(line)) < 2
    n = n + 1;
    header{n} = line;
    line = fgetl(fid);
end
fclose(fid);
fprintf('%s','Loading CSV data...');
csv_filename
trialnum=str2double(csv_filename(find(csv_filename=='.',1,'last')-1));
lastletter=find(csv_filename=='.',1,'last')-1;
firstletter=find(csv_filename=='/',1,'last')+1;
csv_data = dlmread(csv_filename,',',n,0);
csv_data = csv_data'; %to match EEGLAB (frames in cols)

%parse header
csv_header.Fs = csv_sample_rate;
if ~isempty(channel_label_line)
    idx = [0 find(header{channel_label_line} == ',')];
    for i = 1:length(idx)-1
        csv_header.Label{i} = header{channel_label_line}(idx(i)+1:idx(i+1)-1);
    end
    csv_header.Label{i+1} = header{channel_label_line}(idx(i+1)+1:end);
else
    for i = 1:size(csv_data,2)
        csv_header.Label{i} = ['Data ' num2str(i)];
    end
end
csv_sync_ch_idx = find(strcmp(csv_header.Label,csv_sync_channel));

%%
%fix sync
[eeg_trig_latencies csv_trig_latencies EEG csv_data] = fix_sync(EEG, csv_data, csv_sync_ch_idx, csv_sample_rate);
%
%compare csv and EEG trig latencies
eeg_trig_time = eeg_trig_latencies/EEG.srate;
csv_trig_time = csv_trig_latencies/csv_header.Fs;
time_shift = csv_trig_time - eeg_trig_time;
if max(abs(diff(time_shift))) > resample_threshold %triger_offset_tol
        %P = polyfit(biomech_trig_time,time_shift,1); %this line was originally commented, but not uncommented since FixedPtLinReg function below is not present
        P = FixedPtLinReg(csv_trig_time,time_shift,...  
            [-0.1 0.1],0.00001,time_shift(1));
        P(1) = round(P(1)/0.00001)*0.00001;
        P(2) = time_shift(1);
    %P = polyfit(csv_trig_time,time_shift,1);
    if resample_threshold > max(abs(diff(time_shift)))
        %resample automatically
        user_response = 'Resample csv';
        csv_header.Fs = (1+P(1))*csv_header.Fs;
        disp(['csv frame rate Assumed to be: ' num2str((1+P(1))*csv_header.Fs)])
        newFR=input('ok with this?: ','s');
    else
        %display trigger delays and best fit line for frame rate
        finished = false;
        while ~finished
            h = figure; set(gcf,'color','w');
            plot(csv_trig_time,time_shift,'ro');
            hold on; plot(csv_trig_time,polyval(P,csv_trig_time));
            xlabel('time (s)'); ylabel('time shift (s)');
            title(['Max Trigger Offset = ' ...
                num2str(max(abs(diff(time_shift)))) ...
                ':  Frame rate Assumed to be: '...
                num2str((1+P(1))*csv_header.Fs)]);
                finished=true;
        end
        %close(h);
        %pause(1); %pause to close figure;
        
    end
end

%get P and Q for resample.m
%set tol so that P,Q accurate to TRIG_OFFSET_TOL/1000
finished = false;
error_factor = 1000/.9;%1000/.9; %1000 on first iteration
while ~finished
    error_factor = round(error_factor*.9);
    [P_FR,Q_FR] = rat(EEG.srate/csv_header.Fs,...
        0.001/EEG.srate/error_factor);
    if P_FR*Q_FR<2^31 
        %max for int32directory
        finished = true;
    end
end

%convert csv trig latencies to EEG.srate
csv_trig_latencies = round(csv_trig_latencies*P_FR/Q_FR);
csv_trig_time = csv_trig_latencies/EEG.srate;

%loop through all csv data and resample
disp('Resampling csv Data to EEG sample rate...');
for i = 1:size(csv_data,1)
    tmp_data(i,:) = resample(csv_data(i,:),P_FR,Q_FR);
end
csv_data = tmp_data;
csv_header.AssumedOriginalFs = csv_header.Fs;
csv_header.Fs = EEG.srate;
csv_header.samples = size(csv_data,2);
clear tmp_data;

%insert csv data and header into EEG structure
eeg_start_frame = eeg_trig_latencies(1)-csv_trig_latencies(1)+1;
if eeg_start_frame < 1
    csv_start_frame = abs(eeg_start_frame)+2;
    eeg_start_frame = 1;
else
    csv_start_frame = 1;
end
EEG.other_data.csv = [repmat(NaN,size(csv_data,1),eeg_start_frame-1) csv_data(:,csv_start_frame:end)];
EEG.etc.csv_header = csv_header;
EEG.etc.csv_header.samples = size(EEG.other_data.csv,2);
numcols=size(EEG.other_data.csv,1);
if numcols < 26
    EEG.other_data.csv(numcols+1:27,:)=NaN;
end
%insert csv data boundary event
%%%%COME BACK TO THIS
% if eeg_start_frame > 1
%    EEG = eeg_addnewevents(EEG,{[eeg_start_frame]},{['test']});
% end

%make sure that the number of EEG and csv samples are the same
%fill in NaN place holders in csv data at the end if needed or truncate
%the csv data
num_pts_diff = EEG.pnts - size(EEG.other_data.csv,2);
if num_pts_diff > 0
    EEG.other_data.csv(:,EEG.etc.csv_header.samples+1:...
        EEG.etc.csv_header.samples+num_pts_diff) = NaN;
else
    EEG.other_data.csv = EEG.other_data.csv(:,1:EEG.pnts);
end
EEG.etc.csv_header.samples = EEG.pnts;

%plot results

g = figure; set(g,'color','w');%,'name','close figure to continue processing');
plot([1:EEG.pnts]/EEG.srate,EEG.other_data.csv(csv_sync_ch_idx,:));
for i = 1:length(eeg_trig_latencies)
    hold on; plot(repmat(eeg_trig_latencies(i)/EEG.srate,1,2),...
    [min(EEG.other_data.csv(csv_sync_ch_idx,:)) ...
    max(EEG.other_data.csv(csv_sync_ch_idx,:))],...
    'r-','linewidth',2);
end
legend('CSV TRIG','EEG TRIG EVENTS');
xlabel('Time (s)'); title(EEG.setname,'interpreter','none');
drawnow;
% if ~isdir('plots/')
%     mkdir('plots/');
% end
% saveas(g,['plots/' csv_filename(firstletter:lastletter) '_trigger_fixed'])
%uiwait(g);
close(g);
%close(h)
% once satisfied with the alignment, find the gait events
%% finding gait events
disp('finding gait events...');

%EEG.biomech_events=[]; 
%[b,a]=butter(4,56/1024/2); %56 Hz 
%a=[1 -3.7756 5.3515 -3.3748 0.7989];
%b=10e-04*[0.0305 0.1220 0.1830 0.1220 0.0305];

%
FP_Fz = find(strcmp(csv_header.Label,'Fz'));
if isempty(FP_Fz)==0
    FP_Fz_data=EEG.other_data.csv(FP_Fz,:); 
    FP_Fz_data(isnan(FP_Fz_data))=0;
    FP_Fz_data(1,:)=fastsmooth(FP_Fz_data(1,:),50);
    FP_Fz_data(2,:)=fastsmooth(FP_Fz_data(2,:),50);
    FPhalf=length(FP_Fz_data)/2;
    LeftFP_Fz=(FP_Fz_data(1,:)-max(FP_Fz_data(1,FPhalf-50000:FPhalf+50000)));
    RightFP_Fz=(FP_Fz_data(2,:)-max(FP_Fz_data(2,FPhalf-50000:FPhalf+50000)));
    LeftFP_Fz=-LeftFP_Fz;
    RightFP_Fz=-RightFP_Fz;
    %FP_Fz_data=abs(FP_Fz_data);
    
    %LeftFP_Fz=filtfilt(b,a,FP_Fz_data(1,:));
    %RightFP_Fz=filtfilt(b,a,FP_Fz_data(2,:));
    %LeftFP_Fz=LeftFP_Fz-max(LeftFP_Fz);
    %RightFP_Fz=RightFP_Fz-max(RightFP_Fz);
    GRF_threshold= 15;
    % MFP=max(max(FP_Fz_data)); %the incline is not calibrated the same as the flat; must adjust
    % if MFP>20
    %     LeftFP_Fz=LeftFP_Fz-30;
    %     RightFP_Fz=RightFP_Fz-30;
    % end

    left_logical=LeftFP_Fz > GRF_threshold; %makes logical of contact (1 or 0) based on exceeding threshold
    right_logical=RightFP_Fz > GRF_threshold;
    left_heel_strike=find(diff(left_logical)>0); %finds the indices when GRF exceeds threshold
    right_heel_strike=find(diff(right_logical)>0);
    left_toe_off=find(diff(left_logical)<0); %finds the indices when GRF exceeds threshold
    right_toe_off=find(diff(right_logical)<0);

    figure(4); plot(abs(RightFP_Fz)); hold on; plot(right_heel_strike,abs(RightFP_Fz(right_heel_strike)),'r^');
    plot(abs(LeftFP_Fz),'k'); plot(left_heel_strike,abs(LeftFP_Fz(left_heel_strike)),'ro');
    plot(right_toe_off,abs(RightFP_Fz(right_toe_off)),'g^');
    plot(left_toe_off,abs(LeftFP_Fz(left_toe_off)),'go');
    
    drawnow;
    if save_gait_plots==1
        if exist(save_gait_path)
            saveas(gcf,[save_gait_path filesep csv_filename(firstletter:lastletter) '_FZ_FP_fixed.jpg'])
            saveas(gcf,[save_gait_path filesep csv_filename(firstletter:lastletter) '_FZ_FP_fixed'])
        end
    end
    
    
    diff_rightHS=diff(right_heel_strike);
    diff_leftHS=diff(left_heel_strike);
    std_heelstrike=std([diff_rightHS'; diff_leftHS']);
    mean_heelstrike=trimmean([diff_rightHS'; diff_leftHS'],10);

    diff_rightTO=diff(right_toe_off);
    diff_leftTO=diff(left_toe_off);
    std_toeoff=std([diff_rightTO'; diff_leftTO']);
    mean_toeoff=trimmean([diff_rightTO'; diff_leftTO'],10);

    badsteps_rightHS=find(abs(diff_rightHS-mean_heelstrike) > 150);  %if time point is 100 above mean, mark as bad
    badsteps_leftHS=find(abs(diff_leftHS-mean_heelstrike) > 150);  %if time point is 100 above mean, mark as bad
    badsteps_rightTO=find(abs(diff_rightTO-mean_toeoff) > 150);  %if time point is 100 above mean, mark as bad
    badsteps_leftTO=find(abs(diff_leftTO-mean_toeoff) > 150);  %if time point is 100 above mean, mark as bad
    %badsteps_right2=find((right_heel_strike-right_toe_off) < 150); 
    %badsteps_left2=find((left_heel_strike-left_toe_off) < 150); 
    
    disp(['bad right heel strikes: ' num2str((length(badsteps_rightHS)/length(right_heel_strike))*100) '% ('  num2str(length(badsteps_rightHS)) '/'  num2str(length(right_heel_strike)) ')' ]);
    disp(['bad left heel strikes: '  num2str((length(badsteps_leftHS)/length(left_heel_strike))*100) '% ('  num2str(length(badsteps_leftHS)) '/'  num2str(length(left_heel_strike)) ')' ]);
    disp(['bad right toe offs: ' num2str((length(badsteps_rightTO)/length(right_toe_off))*100) '% ('  num2str(length(badsteps_rightTO)) '/'  num2str(length(right_toe_off)) ')' ]);
    disp(['bad left toe offs: '  num2str((length(badsteps_leftTO)/length(left_toe_off))*100) '% ('  num2str(length(badsteps_leftTO)) '/'  num2str(length(left_toe_off)) ')' ]);

    if save_gait_plots==1
        if exist(save_gait_path)
            figure(5); title('difference in heel strike time'); hold on; plot(diff_rightHS); plot(diff_leftHS,'r');
            plot(1:length(diff_rightHS),mean_heelstrike+std_heelstrike*2);
            plot(1:length(diff_rightHS),mean_heelstrike-std_heelstrike*2);
            plot(badsteps_rightHS,diff_rightHS(badsteps_rightHS),'k^');
            plot(badsteps_leftHS,diff_leftHS(badsteps_leftHS),'k^');
            set(gcf,'Position',[100 525 560 420])
            saveas(gcf,[save_gait_path filesep csv_filename(firstletter:lastletter) '_heelstrike_fixed.jpg'])
            
            figure(6); title('difference in toe off time'); hold on; plot(diff_rightTO); plot(diff_leftTO,'r');
            plot(1:length(diff_rightTO),mean_toeoff+std_toeoff*2);
            plot(1:length(diff_rightTO),mean_toeoff-std_toeoff*2);
            plot(badsteps_rightTO,diff_rightTO(badsteps_rightTO),'k^');
            plot(badsteps_leftTO,diff_leftTO(badsteps_leftTO),'k^');
            set(gcf,'Position',[900 525 560 420])
            saveas(gcf,[save_gait_path filesep csv_filename(firstletter:lastletter) '_toeoff_fixed.jpg'])
        end
    end

    deletesteps_rightHS=find(diff_rightHS(badsteps_rightHS)-200<0);
    deletesteps_leftHS=find(diff_leftHS(badsteps_leftHS)-200<0);
    deletesteps_rightTO=find(diff_rightTO(badsteps_rightTO)-200<0);
    deletesteps_leftTO=find(diff_leftTO(badsteps_leftTO)-200<0);
  

    right_heel_strike([1 badsteps_rightHS((deletesteps_rightHS))+1])=NaN;
    left_heel_strike([1 badsteps_leftHS((deletesteps_leftHS))+1])=NaN;
    right_toe_off([1 badsteps_rightTO((deletesteps_rightTO))+1])=NaN;
    left_toe_off([1 badsteps_leftTO((deletesteps_leftTO))+1])=NaN;

    EEG.other_data.LHS=left_heel_strike(~isnan(left_heel_strike));
    EEG.other_data.RHS=right_heel_strike(~isnan(right_heel_strike));
    EEG.other_data.LTO=left_toe_off(~isnan(left_toe_off));
    EEG.other_data.RTO=right_toe_off(~isnan(right_toe_off));
    EEG.other_data.badsteps=[length(badsteps_rightHS) length(badsteps_leftHS) length(badsteps_rightTO) length(badsteps_leftTO)];
    EEG.other_data.badstepsname=['badsteps_rightHS, ', 'badsteps_leftHS, ', 'badsteps_rightTO, ', 'badsteps_leftTO '];
    on=0;
    if on==1
        pickpoint=menu('pick point to fix?','yes','no');
        while pickpoint==1
            diff_right=diff(right_heel_strike);
            diff_left=diff(left_heel_strike);
            std_heelstrike=std([diff_right'; diff_left']);
            mean_heelstrike=mean([diff_right'; diff_left']);
            figure(7); title('difference in step time'); plot(diff_right); hold on; plot(diff_left,'r');
            plot(1:length(diff_right),mean_heelstrike+std_heelstrike*2);
            plot(1:length(diff_right),mean_heelstrike-std_heelstrike*2);
            [tmpHS,tmp]=ginput(1);
            figure(4);
            axis([right_heel_strike(round(tmpHS))-2000 right_heel_strike(round(tmpHS))+2000 -20 40])
            loop=find(right_heel_strike>right_heel_strike(round(tmpHS)),1,'first');
            checking_GRF_points
            pickpoint=menu('pick point to fix?','yes','no');
            clf(5)
            %[right_heel_strike(loop),tmp]=ginput(1);
            %r=plot(right_heel_strike(loop),tmp,'k^','MarkerFaceColor','y','MarkerSize',10);
        end
    end
    close(4); close(5); close(6);
    last = find(csv_filename == '.',1,'last')-1;
    first = find(csv_filename == '/',1,'last')+1;
    curr_base_name=csv_filename(first:last);

    other_data.LHS=EEG.other_data.LHS;
    other_data.RHS=EEG.other_data.RHS;
    other_data.LTO=EEG.other_data.LTO;
    other_data.RTO=EEG.other_data.RTO;
    other_data.badsteps=EEG.other_data.badsteps;
    other_data.badstepsname=EEG.other_data.badstepsname;
    other_data.csv_header=EEG.etc.csv_header;
    other_data.csv=EEG.other_data.csv;
    
    if save_gait_mat == 1
        if ~exist([save_gait_path filesep curr_base_name '_biomech_data.mat'])
            save([save_gait_path filesep curr_base_name '_biomech_data'],'other_data')
        end
    end
    
    
else
    disp(['No force plate data for ' csv_filename(firstletter:lastletter) '! WHA?? grr. moving on....'])
end
%%
% if strcmp(questdlg('Save Set?','Save Question','Yes','No','Yes'),'Yes')
%     %save
%     %you can save here, but there's no eloc locations yet.... so commented out.
%     %EEG = pop_saveset(EEG,'filename',strcat(EEG.setname,'_with_BIOMECH.set')); %jl,'filepath',EEG_dir);
% else
%     disp('EEG set NOT SAVED - continuing to next set...');
% end
