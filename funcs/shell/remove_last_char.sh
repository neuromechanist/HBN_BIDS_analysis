#!/bin/bash
# It turns out that the there is a hidden char that avoids looping through the
# subjects' code to find which EEG files they have. The follwing script will rmove those chars.

input="./eeg_participants.tsv"
while IFS= read -r line
do
    echo "$line" | cat -et | cut -c 1-12 >> eeg_participants_t.tsv
done < "$input"