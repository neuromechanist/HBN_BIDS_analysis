#!/bin/bash

while getopts ":p:d:" opt; do
  case $opt in
    p) pattern="$OPTARG";;
    d) target_dir="$OPTARG";;
    \?) echo "Invalid option: -$OPTARG"; exit 1;;
  esac
done

if [ -z "$pattern" ]; then
  echo "Error: pattern cannot be empty" >&2
  exit 1
fi

if [ ! -d "$target_dir" ]; then
  echo "Error: $target_dir is not a directory" >&2
  exit 1
fi

find "$target_dir" -type f -name "*$pattern*" -delete

