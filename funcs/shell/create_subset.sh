#!/bin/bash

# Shell wrapper for create_subset_dataset.py
# Makes it easier to create subset datasets with common source paths

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/create_subset_dataset.py"

# Default source dataset path
DEFAULT_SOURCE="~/HBN data/cmi_bids_R3_20"

usage() {
    echo "Usage: $0 <output_dataset> <n_subjects> [source_dataset] [--dry-run]"
    echo ""
    echo "Arguments:"
    echo "  output_dataset  : Path where the subset dataset will be created"
    echo "  n_subjects      : Number of subjects to select (with most available data)"
    echo "  source_dataset  : Source BIDS dataset path (optional, defaults to cmi_bids_R3_20)"
    echo "  --dry-run       : Show selected subjects without creating dataset"
    echo ""
    echo "Examples:"
    echo "  $0 /tmp/subset_5 5                    # Create subset with 5 subjects"
    echo "  $0 /tmp/subset_10 10 --dry-run        # Dry run with 10 subjects"
    echo "  $0 /tmp/subset_3 3 /path/to/dataset   # Use custom source dataset"
}

# Check arguments
if [ $# -lt 2 ]; then
    usage
    exit 1
fi

OUTPUT_DATASET="$1"
N_SUBJECTS="$2"
SOURCE_DATASET="$DEFAULT_SOURCE"
DRY_RUN=""

# Process remaining arguments
shift 2
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY_RUN="--dry-run"
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            # Assume it's a custom source dataset path
            if [ -d "$1" ]; then
                SOURCE_DATASET="$1"
            else
                echo "Error: Directory not found: $1"
                exit 1
            fi
            ;;
    esac
    shift
done

# Validate inputs
if [ ! -d "$SOURCE_DATASET" ]; then
    echo "Error: Source dataset not found: $SOURCE_DATASET"
    exit 1
fi

if [ ! -f "$SOURCE_DATASET/participants.tsv" ]; then
    echo "Error: participants.tsv not found in source dataset"
    exit 1
fi

# Run the Python script
echo "Creating subset dataset..."
echo "Source: $SOURCE_DATASET"
echo "Output: $OUTPUT_DATASET"
echo "Subjects: $N_SUBJECTS"

python3 "$PYTHON_SCRIPT" "$SOURCE_DATASET" "$OUTPUT_DATASET" "$N_SUBJECTS" $DRY_RUN 