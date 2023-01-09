%% initialize
subjs = ["PS04" "PS05" "PS06" "PS07" "PS15" "PS16" "PS17" "PS18" ...
        "PS19" "PS20" "PS21" "PS22" "PS23" "PS24" "PS25" "PS26" "PS27"];
trialTypes = ["LEI", "LME", "REI", "RME"];

p2l.eegRepo = "Z:\BRaIN\eeg\PS\EEG2\";
p2l.sTime = "Z:\BRaIN\stepProject\results\time\";
fs = string(filesep);

eegEventVstrideTime = table('Size',[length(subjs) length(trialTypes)],'VariableTypes',...
    repmat("string",1,length(trialTypes)),'VariableNames',trialTypes,'RowNames',subjs);

%% buildup the table
for s = subjs
    for t = trialTypes
        f2l.error = p2l.eegRepo+s+fs+"error_summary"+fs+s+"_"+t+"_duration_error.mat";
        f2l.time = p2l.eegRepo+s+fs+"Events"+fs+s+"_"+t+"_time.mat";
        load(f2l.error,"error2write")
        load(f2l.time,"strideTime")
        eLength =  length(error2write);
        sLength = length(strideTime);
        eegEventVstrideTime{s,t} = "eeg:"+string(eLength)+" stepping:"+string(sLength);
        e = []; eLength =[]; sLength=[];
    end
end