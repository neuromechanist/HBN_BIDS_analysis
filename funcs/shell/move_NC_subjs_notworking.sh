#!/bin/bash

# Create the directory for non-commercial subjects, if it does not already exist
if [ ! -d cmi_bids_NC ]; then
    echo "Creating cmi_bids_NC directory..."
    mkdir -p cmi_bids_NC
    chmod 755 cmi_bids_NC
else
    echo "cmi_bids_NC directory already exists."
fi

# Create or overwrite the new participants.tsv file in cmi_bids_NC
new_participants="cmi_bids_NC/participants.tsv"
echo -e "participant_id\trelease_number\tsex\tage\tehq_total\tcommercial_use\tfull_pheno\tp_factor\tattention\tinternalizing\texternalizing\tRestingState\tDespicableMe\tFunwithFractals\tThePresent\tDiaryOfAWimpyKid\tcontrastChangeDetection_1\tcontrastChangeDetection_2\tcontrastChangeDetection_3\tsurroundSupp_1\tsurroundSupp_2\tseqLearning6target\tseqLearning8target\tsymbolSearch" > "$new_participants"

# Loop through each directory from cmi_bids_R1 to cmi_bids_R11
for dir in cmi_bids_R{1..11}; do

    # Check if the directory exists
    if [ -d "$dir" ]; then
        echo "Processing directory: $dir"
        participants_file="$dir/participants.tsv"
        
        # Check if the participants.tsv file exists inside the directory
        if [ -f "$participants_file" ]; then
            echo "Found participants.tsv in $dir. Parsing for non-commercial use subjects..."

            # Get the participants with 'no' for commercial use
            non_com_subs=$(awk -F"\t" '$6 == "no" { print $1 }' "$participants_file")
            
            # Check if any subjects with 'no' commercial use exist
            if [ -n "$non_com_subs" ]; then
                echo "Found non-commercial subjects in $dir: $non_com_subs"
                
                # Loop over each non-commercial subject
                for sub in $non_com_subs; do
                    # Check if the subject directory exists
                    if [ -d "$dir/$sub" ]; then
                        echo "Moving $sub from $dir to cmi_bids_NC."
                        
                        # Move the subject's corresponding folder to the 'cmi_bids_NC' directory
                        mv "$dir/$sub" "cmi_bids_NC/"
                        
                        # Append the subject's entry to the new participants.tsv file
                        grep "^$sub" "$participants_file" >> "$new_participants"
                        
                        # Remove the subject from the original participants.tsv
                        awk -v subj="$sub" '$1 != subj' "$participants_file" > "${participants_file}.tmp" && mv "${participants_file}.tmp" "$participants_file"
                    else
                        echo "Warning: Subject $sub directory not found in $dir."
                    fi
                done
            else
                echo "No non-commercial subjects found in $dir."
            fi
        else
            echo "Warning: participants.tsv file not found in $dir."
        fi
    else
        echo "Warning: Directory $dir does not exist."
    fi

done

# Copy non-directory root files from cmi_bids_R12 to cmi_bids_NC, excluding participants.tsv
if [ -d cmi_bids_R12 ]; then
    echo "Copying root files from cmi_bids_R12 to cmi_bids_NC..."
    rsync -av --exclude 'participants.tsv' --exclude='*/' cmi_bids_R12/ cmi_bids_NC/
else
    echo "Warning: Directory cmi_bids_R12 does not exist. No root files copied."
fi

echo "Process completed."

# Finalize permissions to ensure the structure is properly accessible
chmod -R 755 cmi_bids_NC

