#!/bin/bash

target_directory="/"

while getopts "k:t:l:d:" opt; do
    case $opt in
        k)
            keyword="$OPTARG"
            ;;
        t)
            temp_folder="$OPTARG"
            ;;
        l)
            log_file="$OPTARG"
            ;;
        d)
            target_directory="$OPTARG"
            ;;
        *)
            echo "Usage: $0 -k <keyword> -t <temp_folder> -l <log_file> [-d <target_directory>]"
            exit 1
            ;;
    esac
done

if [ -z "$keyword" ] || [ -z "$temp_folder" ] || [ -z "$log_file" ]; then
    echo "Usage: $0 -k <keyword> -t <temp_folder> -l <log_file> [-d <target_directory>]"
    exit 1
fi

if [ ! -d "$temp_folder" ]; then
    mkdir "$temp_folder"
fi

if [ -f "$log_file" ]; then
    echo "Log file already exists. Please move or delete the existing log file."
    exit 1
fi

touch "$log_file"

# echo "Keyword: $keyword"
# echo "Temp Folder: $temp_folder"
# echo "Log File: $log_file"
# echo "Target Directory: $target_directory"

find "$target_directory" -type f -iname "*${keyword}*" -not -path "${temp_folder}/*" -exec sh -c "echo '{}' >> $log_file; mv '{}' $temp_folder" \;

echo "Files with the keyword '${keyword}' have been moved to '${temp_folder}'."
echo "File locations have been recorded in '${log_file}'."

