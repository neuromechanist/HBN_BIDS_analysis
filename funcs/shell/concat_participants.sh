#!/bin/bash

# Set the root directory
ROOT_DIR="."

# Create a new file for the master list
MASTER_FILE="${ROOT_DIR}/master_participants_list_0to11.tsv"

# Initialize the master file with headers from the first dataset
head -n 1 "${ROOT_DIR}/hbn_bids_R1/participants.tsv" > "${MASTER_FILE}"

# Loop through all datasets
for i in {0..11}
do
    DATASET_DIR="${ROOT_DIR}/hbn_bids_R${i}"
    PARTICIPANTS_FILE="${DATASET_DIR}/participants.tsv"

    if [ -f "${PARTICIPANTS_FILE}" ]; then
        # Append data (excluding header) to the master file
        tail -n +2 "${PARTICIPANTS_FILE}" >> "${MASTER_FILE}"
    else
        echo "Warning: ${PARTICIPANTS_FILE} not found."
    fi
done

echo "Master participants list created: ${MASTER_FILE}"

