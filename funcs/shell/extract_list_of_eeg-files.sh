#!/bin/bash
# the special characters are removed from EoL in the *_t.tsv files, each line only inculde a single '\n' 
input="./eeg_participants_t.tsv"  # retrieved on 1/4/22
while IFS='\n' read -r line
do
# echo "$line" | cat -et
printf "$line\n" >> eeg_content.txt
aws s3 ls s3://fcp-indi/data/Projects/HBN/EEG/$line/EEG/raw/mat_format/ --no-sign-request >> eeg_content.txt 
done < "$input"

# Sanity check
# for i in {"NDARAA075AMK","NDARAA112DMH","NDARAA117NEJ"}
# do
# printf "$i \n" >> contnt_test.txt
# aaws s3 ls s3://fcp-indi/data/Projects/HBN/EEG/$i/EEG/raw/mat_format/ --no-sign-requestt >> contnt_test.txt
# done