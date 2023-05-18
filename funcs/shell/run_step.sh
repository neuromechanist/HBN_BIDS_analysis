#!/bin/bash

# Default values
file="S3.txt"
count=-1
delay=120

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--file) file="$2"; shift ;;
        -c|--count) count="$2"; shift ;;
        -d|--delay) delay="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Check if file exists and is readable
if [[ ! -r "$file" ]]; then
  echo "Error: $file does not exist or is not readable"
  exit 1
fi

# Loop over subjects in file, limited by count if specified
i=0
while read -r subject; do
    if [[ $count -gt -1 && $i -ge $count ]]; then
        break
    fi

    echo "Processing subject: $subject"

    # in case that this run step is for re-processing of step3, there is a need to rename some folders.
    # sh rename_incr.sh "/home/sshirazi/HBN_EEG/$subject/ICA/"

    sbatch -J "$subject" --export=ALL,i="$subject" /home/sshirazi/_git/HBN_BIDS_analysis/funcs/slurm/run_step.slurm
    # echo "$subject"
    # Add delay between iterations if specified
    if [[ $delay -gt 0 ]]; then
        sleep "$delay"
    fi

    ((i++))
done < "$file"
