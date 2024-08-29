#!/bin/bash

# Function to display help message
show_help() {
    echo "Usage: $0 -i <input_tsv_file> -r <root_directory>"
    echo ""
    echo "Options:"
    echo "  -i    Specify the input TSV file containing participant IDs and targets"
    echo "  -r    Specify the root directory containing participant folders"
    echo "  -h    Show this help message"
}

# Parse command-line options
while getopts ":i:r:h" opt; do
    case ${opt} in
        i )
            input_tsv_file="$OPTARG"
            ;;
        r )
            root_directory="$OPTARG"
            ;;
        h )
            show_help
            exit 0
            ;;
        \? )
            echo "Invalid option: -$OPTARG" >&2
            show_help
            exit 1
            ;;
        : )
            echo "Option -$OPTARG requires an argument." >&2
            show_help
            exit 1
            ;;
    esac
done

# Check if required arguments are provided
if [ -z "$input_tsv_file" ] || [ -z "$root_directory" ]; then
    echo "Error: Missing required arguments." >&2
    show_help
    exit 1
fi

# Read the TSV file line by line (skipping the header)
tail -n +2 "$input_tsv_file" | while IFS=$'\t' read -r participant_id target6 target8
do
    # Extract XXXXX pattern from participant_id (remove 'sub-' prefix)
    participant_number="${participant_id#sub-}"

    # Construct the participant's directory path
    participant_dir="$root_directory/$participant_number"

    # Search for files with 'vis_learn' in their names within the participant's directory
    find "$participant_dir" -type f -name "*vis_learn*" | while IFS= read -r file
    do
        # Determine new file name suffix based on target columns
        new_suffix=""
        if [ "$target6" == "True" ]; then
            new_suffix="6t"
        elif [ "$target8" == "True" ]; then
            new_suffix="8t"
        fi

        # Create the new file name with the suffix
        new_file_name="${file/vis_learn/vis_learn$new_suffix}"

        # Copy the file with the new name
        cp "$file" "$new_file_name"
    done
done

