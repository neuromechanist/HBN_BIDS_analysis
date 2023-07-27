#!/opt/homebrew/bin/bash

cd /Users/yahya/Documents/git/HBN_BIDS_analysis
matlab -nodisplay -batch "step1_intial_filtering_concat('$1', 'mac', 'mbp', 1, 6);"
matlab -nodisplay -batch "step2_incr_rej('$1', {'everyEEG', 'videoEEG'}, 1, 1, 1, 0, 'mac', 'mbp', 6, 0)";

