#!/bin/bash
input="./eeg_participants.tsv"
while IFS= read -r line
do
    printf '%s\n\n' "${line}" >> eeg_participants_m3.tsv
done < "$input"