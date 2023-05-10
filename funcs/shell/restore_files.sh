#!/bin/bash

while getopts "t:l:" opt; do
    case $opt in
        t)
            temp_folder="$OPTARG"
            ;;
        l)
            log_file="$OPTARG"
            ;;
        *)
            echo "Usage: $0 -t <temp_folder> -l <log_file>"
            exit 1
            ;;
    esac
done

if [ -z "$temp_folder" ] || [ -z "$log_file" ]; then
    echo "Usage: $0 -t <temp_folder> -l <log_file>"
    exit 1
fi

if [ ! -f "$log_file" ]; then
    echo "Log file '${log_file}' not found. Please ensure it exists."
    exit 1
fi

while IFS= read -r original_file
do
    file_name="$(basename "${original_file}")"
    temp_file="${temp_folder}/${file_name}"
    if [ -f "${temp_file}" ]; then
        echo "Restoring '${temp_file}' to '${original_file}'"
        mv "${temp_file}" "${original_file}"
    else
        echo "File '${temp_file}' not found in '${temp_folder}'. Skipping."
    fi
done < "$log_file"

rm "$log_file"
echo "Files have been restored to their original locations. Log file has been removed."

