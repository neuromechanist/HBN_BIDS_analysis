"""
compare_twoTSVs.py

Compares two tabular files (CSV/TSV) and prints entries from file B that are not present in file A, based on specified columns.

Usage:
    python compare_twoTSVs.py --fileA path/to/fileA --fileB path/to/fileB --colA 0 --colB 0 --delimiterA ',' --delimiterB '\t' [--output_tsv output.tsv]

Arguments:
    --fileA:      Path to the first file (reference file, e.g., master list)
    --fileB:      Path to the second file (to check if entries are in fileA)
    --colA:       Column index or name in fileA to compare (default: 0)
    --colB:       Column index or name in fileB to compare (default: 0)
    --delimiterA: Delimiter for fileA (default: ',')
    --delimiterB: Delimiter for fileB (default: '\t')
    --output_tsv: Optional. If provided, outputs missing entries as a TSV file.

Example:
    python compare_twoTSVs.py --fileA funcs/tsv/master_participants_list_0to11.tsv --fileB funcs/json/EEG_participants.csv --colA 0 --colB 0 --delimiterA '\t' --delimiterB ',' --output_tsv missing.tsv
"""
import argparse
import pandas as pd

def parse_args():
    parser = argparse.ArgumentParser(description="Compare two tabular files and print entries from fileB not in fileA.")
    parser.add_argument('--fileA', required=True, help='Reference file (e.g., master list)')
    parser.add_argument('--fileB', required=True, help='File to check (e.g., EEG participants)')
    parser.add_argument('--colA', default=0, help='Column index or name in fileA to compare (default: 0)')
    parser.add_argument('--colB', default=0, help='Column index or name in fileB to compare (default: 0)')
    parser.add_argument('--delimiterA', default=',', help='Delimiter for fileA (default: ","). Use "tab" for tab.')
    parser.add_argument('--delimiterB', default=',', help='Delimiter for fileB (default: ","). Use "tab" for tab.')
    parser.add_argument('--output_tsv', default=None, help='Optional: Output missing entries as TSV file')
    parser.add_argument('--strip_prefixA', default='', help='Optional: Prefix to strip from values in fileA before comparison')
    parser.add_argument('--strip_prefixB', default='', help='Optional: Prefix to strip from values in fileB before comparison')
    parser.add_argument('--strip_suffixA', default='', help='Optional: Suffix to strip from values in fileA before comparison')
    parser.add_argument('--strip_suffixB', default='', help='Optional: Suffix to strip from values in fileB before comparison')
    return parser.parse_args()

def resolve_delimiter(delim):
    """Convert delimiter argument to actual character."""
    if delim.lower() in ['tab', '\\t', 't']:
        return '\t'
    return delim

def get_column(df, col):
    """Return a pandas Series for the specified column (by index or name)."""
    try:
        col_idx = int(col)
        return df.iloc[:, col_idx]
    except ValueError:
        return df[col]

def normalize_series(series, prefix='', suffix=''):
    s = series.astype(str)
    if prefix:
        s = s.str.removeprefix(prefix)
    if suffix:
        s = s.str.removesuffix(suffix)
    return s.str.strip()

def main():
    args = parse_args()
    delimA = resolve_delimiter(args.delimiterA)
    delimB = resolve_delimiter(args.delimiterB)
    # Read files
    dfA = pd.read_csv(args.fileA, delimiter=delimA, dtype=str)
    dfB = pd.read_csv(args.fileB, delimiter=delimB, dtype=str)
    # Get columns to compare and normalize
    colA = get_column(dfA, args.colA).dropna()
    colB = get_column(dfB, args.colB).dropna()
    colA = normalize_series(colA, args.strip_prefixA, args.strip_suffixA)
    colB = normalize_series(colB, args.strip_prefixB, args.strip_suffixB)
    # Find entries in B not in A
    missing_mask = ~colB.isin(colA)
    missing = colB[missing_mask]
    print(f"Entries in {args.fileB} (column {args.colB}) not in {args.fileA} (column {args.colA}):")
    for val in missing.unique():
        print(val)
    # Optionally output as TSV with all columns from B
    if args.output_tsv:
        missing_rows = dfB.loc[missing_mask]
        missing_rows.to_csv(args.output_tsv, sep='\t', index=False)
        print(f"Missing entries with all columns written to {args.output_tsv}")

if __name__ == "__main__":
    main()