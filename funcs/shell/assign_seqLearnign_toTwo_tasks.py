import pandas as pd
import argparse

# Set up argument parser
parser = argparse.ArgumentParser(description="Update 6_target and 8_target based on seqLearning flag.")
parser.add_argument('--input', type=str, default='master_participants_list_short.tsv', help='Input TSV file path')
parser.add_argument('--output', type=str, default='updated_participants.tsv', help='Output TSV file path')

args = parser.parse_args()

# Load the TSV file
df = pd.read_csv(args.input, sep='\t')

# Iterate through the DataFrame and update the 6_target and 8_target columns
for index, row in df.iterrows():
    if row['6_target'] == True:
        df.at[index, '6_target'] = row['seqLearning']
        df.at[index, '8_target'] = 'unavailable'
    elif row['8_target'] == True:
        df.at[index, '8_target'] = row['seqLearning']
        df.at[index, '6_target'] = 'unavailable'

# Drop the seqLearning column
df = df.drop(columns=['seqLearning'])

# Save the updated DataFrame back to a TSV file
df.to_csv(args.output, sep='\t', index=False)

print(f"Updated participants.tsv has been saved to {args.output}")