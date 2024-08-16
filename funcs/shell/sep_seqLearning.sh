#!/bin/bash

# Set the BIDS root directory
BIDS_DIR="."

# Copy participants.tsv to a new file
cp "$BIDS_DIR/participants.tsv" "$BIDS_DIR/participants_updated.tsv"

# Process each participant
while IFS=$'\t' read -r participant_id rest; do
    if [[ $participant_id == participant_id ]]; then
        continue  # Skip the header
    fi

    events_file="$BIDS_DIR/$participant_id/eeg/${participant_id}_task-seqLearning_events.tsv"
    
    if [[ -f $events_file ]]; then
        target_count=$(awk 'NR>1 && $NF ~ /^[0-9]+$/ {print $NF; exit}' "$events_file")
        
        if [[ $target_count -eq 6 ]]; then
            sed -i "s/^$participant_id\t.*$/&\ttrue\tfalse/" "$BIDS_DIR/participants_updated.tsv"
        elif [[ $target_count -eq 8 ]]; then
            sed -i "s/^$participant_id\t.*$/&\tfalse\ttrue/" "$BIDS_DIR/participants_updated.tsv"
        else
            sed -i "s/^$participant_id\t.*$/&\tfalse\tfalse/" "$BIDS_DIR/participants_updated.tsv"
        fi
    else
        sed -i "s/^$participant_id\t.*$/&\tfalse\tfalse/" "$BIDS_DIR/participants_updated.tsv"
    fi
done < "$BIDS_DIR/participants.tsv"

# Add the new column headers
sed -i '1s/$/\t6_target\t8_target/' "$BIDS_DIR/participants_updated.tsv"

echo "Updated participants file created: $BIDS_DIR/participants_updated.tsv"

