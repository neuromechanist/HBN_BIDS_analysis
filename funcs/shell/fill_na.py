import pandas as pd

# Read the TSV file
df = pd.read_csv('your_file.tsv', sep='\t')

# Fill missing values with 'n/a'
df.fillna('n/a', inplace=True)

# Save the updated DataFrame back to a TSV file
df.to_csv('updated_file.tsv', sep='\t', index=False)
