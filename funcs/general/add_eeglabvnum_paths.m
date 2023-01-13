function add_eeglabvnum_paths(eeglab_vnum)

if strcmp(eeglab_vnum, '8')
    addpath(genpath('/home/admin/eeglab8_0_3_5b/'));
elseif strcmp(eeglab_vnum, '10')
    addpath(genpath('/home/admin/eeglab10_1_2_0b/'));
elseif strcmp(eeglab_vnum, '12')
    addpath(genpath('/share/data3/hjhuang/EEGLAB/eeglab12_0_2_5b/'));
elseif strcmp(eeglab_vnum, '13.0.1b')
    addpath(genpath('/share/data3/hjhuang/EEGLAB/eeglab13_0_1b/'));
elseif strcmp(eeglab_vnum, '13.1.1b')
    addpath(genpath('/share/data3/hjhuang/EEGLAB/eeglab13_1_1b/'));
elseif strcmp(eeglab_vnum, '13.3.2b')
    addpath(genpath('/share/data3/hjhuang/EEGLAB/eeglab13_3_2b/'));
end

