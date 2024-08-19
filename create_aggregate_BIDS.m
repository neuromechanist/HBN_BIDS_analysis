% Create_Aggregate_BIDS
% calling convert_HBN2BIDS in a way that creates the correct BIDs structure
% Multi-run tasks should be run together, but the single-run tasks should
% be called on by one.
%
% (c) Seyed Yahya Shirazi, 10/2023 SCCN, INC, UCSD

target_tasks = ["SAIIT_2AFC_Block1", "SAIIT_2AFC_Block2", "SAIIT_2AFC_Block3"];
convert_HBN2BIDS(target_tasks);

target_tasks = ["SurroundSupp_Block1", "SurroundSupp_Block2"];
convert_HBN2BIDS(target_tasks);

target_tasks = ["RestingState", "Video_DM", "Video_FF", "Video_TP", "Video_WK", "vis_learn", "WISC_ProcSpeed"];
for t = target_tasks
    convert_HBN2BIDS(t);
end

%% create the nice participant.tsv file
convert_HBN2BIDS([],1);


%% seperating seqLearning
target_tasks = ["vis_learn8t"];
for t = target_tasks
    convert_HBN2BIDS(t);
end