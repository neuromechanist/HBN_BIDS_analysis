#!/bin/bash

# Check if filename argument is provided
if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <filename>"
  exit 1
fi

# Check if file exists and is a regular file
if [[ ! -f "$1" ]]; then
  echo "Error: $1 does not exist or is not a regular file"
  exit 1
fi

# Replace tabs with new lines
sed 's/\t/\n/g' "$1" > "$1.tmp"

# Move the temporary file to the original filename
mv "$1.tmp" "$1"

echo "Tabs replaced with new lines in $1"

