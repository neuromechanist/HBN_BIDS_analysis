#!/bin/bash

# Check that the user provided a path to the directory
if [ $# -ne 1 ]; then
  echo "Usage: $0 /path/to/directory"
  exit 1
fi

# Check that the provided path is a directory
if [ ! -d "$1" ]; then
  echo "Error: $1 is not a directory"
  exit 1
fi

# Loop over directories that match the pattern incr0*
for dir in "$1"/incr0*; do
  # If the directory is named incr0, skip it
  if [[ "$dir" == "$1/incr0" ]]; then
    continue
  fi

  # Get the new directory name by replacing the "0" with an empty string
  newdir=${dir/0/}

  # Rename the directory
  mv "$dir" "$newdir"
done

