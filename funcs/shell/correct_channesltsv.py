import os
import pandas as pd

# Define the root directories for the EEG-BIDS datasets
root_dirs = [f"cmi_bids_R{num}" for num in range(1, 10)] + ["cmi_bids_NC"]


# Function to update _channels.tsv files
def update_channels_ts(ds_path):
    eeg_dir = os.path.join(ds_path, 'eeg')
    if os.path.isdir(eeg_dir):
        for filename in os.listdir(eeg_dir):
            if filename.endswith('_channels.tsv'):
                file_path = os.path.join(eeg_dir, filename)
                print(f'Updating file: {file_path}')

                # Load the TSV file into a DataFrame
                df = pd.read_csv(file_path, sep='\t')

                # Update the 'type' and 'units' columns
                df['type'] = 'EEG'
                df['units'] = 'uV'

                # Save the updated DataFrame back to TSV
                df.to_csv(file_path, sep='\t', index=False)


# Loop over each root directory and update channels files
for root_dir in root_dirs:
    if os.path.isdir(root_dir):
        # Loop through each subject directory
        for subdir, dirs, files in os.walk(root_dir):
            # Update channels files in the current subject's EEG directory
            update_channels_ts(subdir)
