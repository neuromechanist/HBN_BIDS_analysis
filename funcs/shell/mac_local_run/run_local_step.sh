#! /opt/homebrew/bin/bash

# Default values
file="sample_subjs.txt"
delay=0
script="step1.sh"  # default script
reprocess=0

start=1
end=-1

# Help function
function show_help {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "-h, --help              Show help"
    echo "-f, --file FILE         Specify the file to read subjects from (default: sample_subjs.txt)"
    echo "-c, --count RANGE       Specify the range of subjects to process (default: 1:-1, process all)"
    echo "-d, --delay DELAY       Add delay between iterations in seconds (default: 0)"
    echo "-s, --script SCRIPT     Specify the slurm script to run (default: step1.sh)"
    echo "-r, --reprocess FLAG    Specify if the script needs to reprocess (default: 0)"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) show_help; exit 0 ;;
        -f|--file) file="$2"; shift ;;
        -c|--count) IFS=":" read -r start end <<< "$2"; shift ;;
        -d|--delay) delay="$2"; shift ;;
        -s|--script) script="$2"; shift ;;
        -r|--reprocess) reprocess="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Check if file exists and is readable
if [[ ! -r "$file" ]]; then
    echo "Error: $file does not exist or is not readable"
    exit 1
fi

# Load subjects into array
mapfile -t subjects < "$file"

# If end is -1, set it to last index
if [[ $end -eq -1 ]]; then
    end=${#subjects[@]}
fi

# Adjust for array being 0-indexed
((start--))
((end--))
cd /Users/yahya/Documents/git/HBN_BIDS_analysis/funcs/shell/mac_local_run/
# Loop over subjects in specified range
for ((i=start; i<=end; i++)); do
    subject="${subjects[$i]}"
    echo "Processing subject: $subject"

    if [[ $reprocess -gt 0 ]]; then
        # in case that this run step is for re-processing of step3, there is a need to rename some folders.
        sh ./rename_incr.sh "/Volumes/Yahya/Datasets/HBN/EEG/$subject/ICA/"
    fi
    echo "./$script"
    "./$script '$subject'"

    # Add delay between iterations if specified
    if [[ $delay -gt 0 ]]; then
        sleep "$delay"
    fi
done

