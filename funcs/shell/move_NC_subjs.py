#!/usr/bin/env python3

import os
import shutil
import pandas as pd

# Paths
nc_dir = "cmi_bids_NC"

# Create output directory if not exists
if not os.path.exists(nc_dir):
    print(f"Creating new non-commercial dataset directory: {nc_dir}")
    os.makedirs(nc_dir)
else:
    print(f"Non-commercial dataset directory {nc_dir} already exists.")

# Create an empty participants.tsv for the new dataset
new_participants_path = os.path.join(nc_dir, "participants.tsv")

# We'll create an empty pandas DataFrame and append to its rows later
new_participants_df = pd.DataFrame()

# Loop through each `cmi_bids_R{X}` directory from R1 to R11
for ri in range(1, 12):
    directory = f"cmi_bids_R{ri}"
    
    # Check if directory exists
    if not os.path.exists(directory):
        print(f"Warning: Directory {directory} does not exist.")
        continue
    
    participants_file = os.path.join(directory, "participants.tsv")
    
    # Load the participants.tsv file if it exists
    if os.path.exists(participants_file):
        print(f"Processing participants.tsv in {directory}...")

        # Load the participants.tsv into a Pandas DataFrame
        df = pd.read_csv(participants_file, sep="\t")
        
        # Filter rows that have 'no' in the `commercial_use` column
        non_com_df = df[df['commercial_use'].str.lower() == 'no']
        
        if not non_com_df.empty:
            print(f"Found non-commercial subjects in {directory}.")

            # Move each non-commercial subject directory
            for participant_id in non_com_df['participant_id']:
                subject_dir = os.path.join(directory, participant_id)
                if os.path.exists(subject_dir):
                    dest_dir = os.path.join(nc_dir, participant_id)
                    print(f"Moving {participant_id} from {subject_dir} to {dest_dir}.")
                    shutil.move(subject_dir, dest_dir)
                else:
                    print(f"Subject directory {participant_id} not found in {directory}.")
            
            # Append non-commercial subjects to the new participants.tsv
            new_participants_df = pd.concat([new_participants_df, non_com_df], ignore_index=True)
            
            # Remove non-commercial subjects from original participants.tsv
            commercial_df = df[df['commercial_use'].str.lower() != 'no']
            commercial_df.to_csv(participants_file, sep="\t", index=False)
        else:
            print(f"No non-commercial subjects found in {directory}.")
    else:
        print(f"Warning: {participants_file} not found.")

# Save the combined participants.tsv for non-commercial subjects
if not new_participants_df.empty:
    print(f"Writing updated participants.tsv for {nc_dir} dataset.")
    new_participants_df.to_csv(new_participants_path, sep="\t", index=False)
else:
    print("No non-commercial subjects were found across datasets. Skipping creation of a new participants.tsv.")

# Lastly, copy non-directory root files from cmi_bids_R12
root_dir_r12 = "cmi_bids_R12"
if os.path.exists(root_dir_r12):
    print(f"Copying root files from {root_dir_r12} to {nc_dir} (excluding participants.tsv)...")
    
    for item in os.listdir(root_dir_r12):
        item_path = os.path.join(root_dir_r12, item)
        
        # Exclude directories and participants.tsv
        if os.path.isfile(item_path) and item != 'participants.tsv':
            shutil.copy2(item_path, nc_dir)
            print(f"Copied {item} to {nc_dir}.")
else:
    print(f"Warning: Root directory {root_dir_r12} does not exist. No root files copied.")
    
print("Process completed.")

