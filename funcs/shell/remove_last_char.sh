#!/bin/bash
input="./eeg_participants.tsv"
while IFS= read -r line
do
    echo "$line" | cat -et | cut -c 1-12 >> eeg_participants_t.tsv
done < "$input"