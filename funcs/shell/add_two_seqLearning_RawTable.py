# %% Import necessary libraries and handle the data
import pandas as pd

# Load the participant list and sequence learning binary files
participants_df = pd.read_csv('../tsv/participants_augmented_filesize.csv')
seq_learning_df = pd.read_csv('../tsv/seqLearning_binary.tsv', sep='\t')

# Add two new columns to the participant list and set their initial values to 0
participants_df['vis_learn6t'] = 0
participants_df['vis_learn8t'] = 0

# Parse participant IDs in the sequence learning file by removing the 'sub-' prefix
seq_learning_df['participant_id'] = seq_learning_df['participant_id'].str.replace('sub-', '')

# Convert TRUE/FALSE strings to actual booleans if necessary
# seq_learning_df['6_target'] = seq_learning_df['6_target'].apply(lambda x: True if x == 'TRUE' else False)
# seq_learning_df['8_target'] = seq_learning_df['8_target'].apply(lambda x: True if x == 'TRUE' else False)

# %% Iterate through the sequence learning file
for _, row in seq_learning_df.iterrows():
    participant_id = row['participant_id']

    # Find the corresponding row in the participant list
    participant_row = participants_df[participants_df['participant_id'] == participant_id]

    # Update vis_learn6t and vis_learn8t if conditions are met
    if row['6_target']:
        participants_df.loc[participants_df['participant_id'] == participant_id, 'vis_learn6t'] =\
            participant_row['vis_learn'].values[0]

    if row['8_target']:
        participants_df.loc[participants_df['participant_id'] == participant_id, 'vis_learn8t'] =\
            participant_row['vis_learn'].values[0]

# %% Save the updated participant list to a new CSV file
participants_df.to_csv('../tsv/participants_augmented_filesize_twoSeqLearning', index=False)
