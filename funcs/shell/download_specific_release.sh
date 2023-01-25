#!/bin/bash

# Download the participants.tsv file
aws s3 cp s3://fcp-indi/data/Projects/HBN/EEG/participants.tsv . --no-sign-request

# Filter out subjects in Release 3
grep "R3" participants.tsv > participants_r3.tsv

# Extract subject folder names
awk '{print $2}' participants_r3.tsv > subject_folders_r3.txt

# Download subject folders
for subject in $(cat subject_folders_r3.txt); do
    aws s3 cp s3://fcp-indi/data/Projects/HBN/EEG/$subject ~/yahya/R3/$subject --recursive --no-sign-request
done
