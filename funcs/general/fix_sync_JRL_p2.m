%% fixing the vicon and biosemi sync issues  %%%%%%%%%
%  J. Lukos 05/22/2013, Army Research Laboratory %%%%%

% p1 = wrong eeg event code, falling edge 32776, delete 1st EEG

function [new_eeg_trig_latencies new_csv_trig_latencies EEG new_biomech] = fix_sync_JRL_p2(EEG, csv_filename,csv_data, csv_sync_ch_idx, csv_sample_rate)

eeg_trig_latencies = cell2mat(get_EEG_event_array(EEG,8,'latency'));
eeg_trig_event= cell2mat(get_EEG_event_array(EEG,8,'urevent'));

if eeg_trig_latencies(1) == 1
    disp('deleted first EEG trigger')
   eeg_trig_latencies(1) = []; %this means the sync was on when the recording started. We don't want this, we want rising edges
end

%offset sync so it is zero based
csv_data(csv_sync_ch_idx,:) = csv_data(csv_sync_ch_idx,:)-min(csv_data(csv_sync_ch_idx,:));

%define csv trigger latencies
csv_trig_latencies = [];

%if sync channel returned to zero for one frame consider this to be
%noise and use only the first onset event
csv_trig_latencies(find(diff(csv_trig_latencies) <= 2)+1) = [];
for i = 1:size(csv_data,2)-1
    if csv_data(csv_sync_ch_idx,i) < 2 && csv_data(csv_sync_ch_idx,i+1) > 2
        csv_trig_latencies(length(csv_trig_latencies)+1) = i+1;
    end
end

figure(100);
csv_frames = (csv_data(1,:)-1)*10+csv_data(2,:); % - 1 so that frames start at 0 instead of 1
plot(csv_frames./csv_sample_rate, csv_data(csv_sync_ch_idx,:));
hold on
plot(csv_trig_latencies./csv_sample_rate, ones(size(csv_trig_latencies))*max(csv_data(csv_sync_ch_idx,:))*0.95, 'kx', 'markersize', 10)
plot(eeg_trig_latencies./EEG.srate, ones(size(eeg_trig_latencies))*max(csv_data(csv_sync_ch_idx,:))*0.9, 'rx', 'markersize', 10)
xlabel('Time (s)');
ylabel('magnitude');
legend({'sync signal' 'Original CSV trig' 'Original EEG trig'})
keyboard

%% fixing sync
% csv file
square_period = 1/(118/60/2); %stride_freq = steps/min * 1 min/60 sec * 1 stride/2 steps
new_biomech=csv_data(:,1:csv_trig_latencies(1)-1);
for loop=1:length(csv_trig_latencies)-1
    if csv_trig_latencies(loop+1)-csv_trig_latencies(loop)~=csv_sample_rate*square_period
        offset=(csv_trig_latencies(loop+1)-csv_trig_latencies(loop)-1)/(csv_sample_rate*square_period-1);
        tmp_time=csv_trig_latencies(loop):offset:csv_trig_latencies(loop+1)-1;
        for j=1:size(csv_data,1)
            new_data(j,:)=interp1([csv_trig_latencies(loop):1:csv_trig_latencies(loop+1)-1],csv_data(j,csv_trig_latencies(loop):csv_trig_latencies(loop+1)-1),tmp_time,'spline');
        end
        new_biomech=horzcat(new_biomech,new_data);
    else
        old_data=[csv_data(:,csv_trig_latencies(loop):csv_trig_latencies(loop+1)-1)];     
        new_biomech=horzcat(new_biomech,old_data);
    end
end
new_biomech=horzcat(new_biomech,csv_data(:,csv_trig_latencies(end):end));
new_csv_trig_latencies = [];
for i = 1:size(new_biomech,2)-1
    if new_biomech(csv_sync_ch_idx,i) < 2 && new_biomech(csv_sync_ch_idx,i+1) > 2
        new_csv_trig_latencies(length(new_csv_trig_latencies)+1) = i+1;
    end
end

% eeg file
new_eeg=EEG.data(:,1:eeg_trig_latencies(1)-1);
for loop=1:length(eeg_trig_latencies)-1
    if eeg_trig_latencies(loop+1)-eeg_trig_latencies(loop)~=EEG.srate*square_period
        offset=(eeg_trig_latencies(loop+1)-eeg_trig_latencies(loop)-1)/(EEG.srate*square_period-1);
        tmp_time=eeg_trig_latencies(loop):offset:eeg_trig_latencies(loop+1)-1;
        for j=1:size(EEG.data,1)
            eeg_data(j,:)=interp1([eeg_trig_latencies(loop):1:eeg_trig_latencies(loop+1)-1],EEG.data(j,eeg_trig_latencies(loop):eeg_trig_latencies(loop+1)-1),tmp_time);
        end
        new_eeg=horzcat(new_eeg,eeg_data);
        EEG.event(eeg_trig_event(loop+1)).latency=length(new_eeg);
    else
        old_eeg=[EEG.data(:,eeg_trig_latencies(loop):eeg_trig_latencies(loop+1)-1)];     
        new_eeg=horzcat(new_eeg,old_eeg);
        EEG.event(eeg_trig_event(loop+1)).latency=length(new_eeg);
    end
end
new_eeg=horzcat(new_eeg,EEG.data(:,csv_trig_latencies(end):end));
EEG.data=new_eeg;
EEG.pnts=length(EEG.data);
new_eeg_trig_latencies = cell2mat(get_EEG_event_array(EEG,8,'latency'));

%remove trailing sync events so eeg and csv have the same number
if length(eeg_trig_latencies) > length(csv_trig_latencies)
    eeg_trig_latencies = eeg_trig_latencies(1:length(csv_trig_latencies));
    new_eeg_trig_latencies = new_eeg_trig_latencies(1:length(new_csv_trig_latencies));
else
    csv_trig_latencies = csv_trig_latencies(1:length(eeg_trig_latencies));
    new_csv_trig_latencies = new_csv_trig_latencies(1:length(new_eeg_trig_latencies));
end

%%
   
%compare csv and EEG trig latencies
old_eeg_trig_time = eeg_trig_latencies/EEG.srate;
new_eeg_trig_time = new_eeg_trig_latencies/EEG.srate;
old_csv_trig_time = csv_trig_latencies/csv_sample_rate;
new_csv_trig_time = new_csv_trig_latencies/csv_sample_rate;
time_shift=[];
length(new_csv_trig_time)
length(new_eeg_trig_time)
time_shift(1,:) = old_csv_trig_time - old_eeg_trig_time;
time_shift(2,:) = new_csv_trig_time - new_eeg_trig_time;
lastletter=find(csv_filename=='.',1,'last')-1;
firstletter=find(csv_filename=='/',1,'last')+1;
y=figure; plot(diff(old_csv_trig_time)); hold on;  plot(diff(old_eeg_trig_time),'r'); plot(diff(new_csv_trig_time),'g.'); plot(diff(new_eeg_trig_time),'r.');
title('sync data','Interpreter','none'); legend('biomech old','EEG','biomech new'); 
% saveas(y,['plots/' csv_filename(firstletter:lastletter) '_synctime']);
x=figure; plot(old_csv_trig_time,time_shift(1,:),'ro'); hold on; plot(new_csv_trig_time,time_shift(2,:),'bo');
title('time shift','Interpreter','none'); legend('old','new'); 
% saveas(x,['plots/' csv_filename(firstletter:lastletter) '_timeshift']);
% close(y); close(x);

figure
subplot(121)
plot(old_eeg_trig_time, 'ko')
hold on, plot(old_csv_trig_time, 'kx')
plot(new_eeg_trig_time, 'ro')
plot(new_csv_trig_time, 'rx')
ylabel('Time of trigger (s)'); xlabel('Event number')
legend({'old eeg trig' 'old csv trig' 'new eeg trig' 'new csv trig'})

subplot(122)
plot(old_eeg_trig_time(1:10), 'ko', 'linewidth', 2)
hold on, plot(old_csv_trig_time(1:10), 'kx', 'linewidth', 2)
plot(new_eeg_trig_time(1:10), 'ro', 'linewidth', 2)
plot(new_csv_trig_time(1:10), 'rx', 'linewidth', 2)
title('First 10 events')
ylabel('Time of trigger (s)'); xlabel('Event number')
legend({'old eeg trig' 'old csv trig' 'new eeg trig' 'new csv trig'})

figure(100);
plot(old_eeg_trig_time, ones(size(eeg_trig_latencies))*max(csv_data(csv_sync_ch_idx,:))*0.9, 'ro', 'markersize', 10)
plot(new_eeg_trig_time, ones(size(new_eeg_trig_latencies))*max(csv_data(csv_sync_ch_idx,:))*0.9, 'r+', 'markersize', 10)

plot(old_csv_trig_time, ones(size(csv_trig_latencies))*max(csv_data(csv_sync_ch_idx,:))*0.95, 'ko', 'markersize', 10)
plot(new_csv_trig_time, ones(size(new_csv_trig_latencies))*max(csv_data(csv_sync_ch_idx,:))*0.95, 'k+', 'markersize', 10)
legend({'sync signal' 'Original CSV trig' 'Original EEG trig' 'Old EEG trig' 'New EEG trig' 'Old CSV trig' 'New CSV trig'})

keyboard

