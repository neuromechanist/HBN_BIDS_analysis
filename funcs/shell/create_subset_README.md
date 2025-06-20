# BIDS Dataset Subset Creation Scripts

This directory contains scripts to create subset BIDS datasets by selecting subjects with the most available data.

## Scripts

### 1. `create_subset_dataset.py`

**Main Python script** that does the heavy lifting:
- Reads `participants.tsv` from source dataset
- Counts "available" entries per subject across task columns
- Selects top N subjects with most available data
- Creates new dataset with only selected subjects
- Copies all root-level files and selected subject directories

**Usage:**

```bash
python3 create_subset_dataset.py <source_dataset> <output_dataset> <n_subjects> [--dry-run]
```

**Example:**

```bash
python3 create_subset_dataset.py "/path/to/cmi_bids_R3_20" "/path/to/subset_10" 10 --dry-run
```

### 2. `create_subset.sh`

**Shell wrapper script** that provides a simpler interface with default paths:
- Uses default source dataset path for CMI BIDS R3.20
- Simplified command-line interface
- Built-in validation and help

**Usage:**

```bash
./create_subset.sh <output_dataset> <n_subjects> [source_dataset] [--dry-run]
```

**Examples:**

```bash
# Create subset with 5 subjects (using default source)
./create_subset.sh /tmp/subset_5 5

# Dry run with 10 subjects
./create_subset.sh /tmp/subset_10 10 --dry-run

# Use custom source dataset
./create_subset.sh /tmp/subset_3 3 /path/to/custom/dataset

# Show help
./create_subset.sh --help
```

## How It Works

1. **Data Analysis**: Script reads `participants.tsv` and identifies task columns:
   - RestingState
   - DespicableMe  
   - FunwithFractals
   - ThePresent
   - DiaryOfAWimpyKid
   - contrastChangeDetection_1/2/3
   - surroundSupp_1/2
   - seqLearning
   - symbolSearch

2. **Subject Selection**: For each subject, counts how many tasks have "available" status (vs "caution" or "unavailable")

3. **Ranking**: Subjects are sorted by availability count (descending), then by participant ID for consistency

4. **Dataset Creation**:
   - Copies all root-level files (JSON sidecars, README, etc.)
   - Copies only selected subject directories
   - Creates new `participants.tsv` with only selected subjects

## Output

The script shows:
- List of selected subjects with their availability counts
- Statistics (min/max/average available tasks)
- Progress during file copying (if not dry-run)

## Example Output

```bash
Top 5 subjects with most available data:
============================================================
sub-NDARAD774HAZ: 12 available tasks
sub-NDARAG340ERT: 12 available tasks  
sub-NDARBA839HLG: 12 available tasks
sub-NDARBM642JFT: 12 available tasks
sub-NDARAA948VFH: 11 available tasks

Available data statistics:
Minimum available tasks: 11
Maximum available tasks: 12
Average available tasks: 11.8
```

## Requirements

- Python 3 (uses only standard library modules: csv, pathlib, shutil, argparse)
- No external dependencies required

## Use Cases

- Create smaller datasets for testing/development
- Select high-quality subjects for analysis
- Generate training/validation splits based on data completeness
- Prepare datasets for sharing with specific subject counts
