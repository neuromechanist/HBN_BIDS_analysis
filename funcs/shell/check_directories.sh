#!/bin/bash

# Usage: ./check_directories.sh target_directory output_file.tsv

TARGET_DIR=$1
OUTPUT_FILE=$2

# Create the header for the TSV file
echo -e "Subdirectory\tBehavioral\tEEG\tEyetracking" > $OUTPUT_FILE

# Loop through each subdirectory in the target directory
for subdir in "$TARGET_DIR"/*; do
  if [ -d "$subdir" ]; then
    subdir_name=$(basename "$subdir")
    
    # Check for the presence of the directories
    behavioral=0
    eeg=0
    eyetracking=0
    
    if [ -d "$subdir/Behavioral" ]; then
      behavioral=1
    fi
    
    if [ -d "$subdir/EEG" ]; then
      eeg=1
    fi
    
    if [ -d "$subdir/Eyetracking" ]; then
      eyetracking=1
    fi
    
    # Append the results to the TSV file
    echo -e "$subdir_name\t$behavioral\t$eeg\t$eyetracking" >> $OUTPUT_FILE
  fi
done

echo "Check completed. Results saved to $OUTPUT_FILE"
