#!/usr/bin/env python3
"""
Create a subset BIDS dataset by selecting subjects with the most available data.

This script reads participants.tsv, counts "available" entries per subject across
task columns, selects the top n subjects, and creates a new dataset with only
those subjects.

Usage:
    python create_subset_dataset.py <source_dataset> <output_dataset> <n_subjects>

Example:
    python create_subset_dataset.py /path/to/cmi_bids_R3_20 /path/to/subset_dataset 10
"""

import sys
import os
import shutil
import csv
import argparse
from pathlib import Path


def read_participants_tsv(file_path):
    """Read participants.tsv and return data as list of dictionaries."""
    participants = []
    
    with open(file_path, 'r', newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f, delimiter='\t')
        for row in reader:
            participants.append(row)
    
    return participants


def count_available_data(participants):
    """Count 'available' entries per subject across task columns."""
    # Task columns (these should match the actual column names in your TSV)
    task_columns = [
        'RestingState', 'DespicableMe', 'FunwithFractals', 'ThePresent', 
        'DiaryOfAWimpyKid', 'contrastChangeDetection_1', 'contrastChangeDetection_2', 
        'contrastChangeDetection_3', 'surroundSupp_1', 'surroundSupp_2', 
        'seqLearning', 'symbolSearch'
    ]
    
    # Count 'available' entries for each subject
    for participant in participants:
        available_count = 0
        for column in task_columns:
            if column in participant and participant[column] == 'available':
                available_count += 1
        participant['available_count'] = available_count
    
    return participants, task_columns


def select_top_subjects(participants, n_subjects):
    """Select top n subjects with most available data."""
    # Sort by available_count (descending) and then by participant_id for consistency
    participants_sorted = sorted(participants, 
                                key=lambda x: (-x['available_count'], x['participant_id']))
    
    # Select top n subjects
    selected_subjects = participants_sorted[:n_subjects]
    
    print(f"\nTop {n_subjects} subjects with most available data:")
    print("="*60)
    for participant in selected_subjects:
        print(f"{participant['participant_id']}: {participant['available_count']} available tasks")
    
    return selected_subjects


def copy_root_files(source_dir, output_dir, exclude_patterns=None):
    """Copy all root-level files except subject directories and participants.tsv."""
    if exclude_patterns is None:
        exclude_patterns = ['sub-*', 'participants.tsv']
    
    source_path = Path(source_dir)
    output_path = Path(output_dir)
    
    # Create output directory if it doesn't exist
    output_path.mkdir(parents=True, exist_ok=True)
    
    for item in source_path.iterdir():
        # Skip if item matches exclude patterns
        if any(item.match(pattern) for pattern in exclude_patterns):
            continue
            
        dest_item = output_path / item.name
        
        if item.is_file():
            print(f"Copying file: {item.name}")
            shutil.copy2(item, dest_item)
        elif item.is_dir():
            print(f"Copying directory: {item.name}")
            shutil.copytree(item, dest_item, dirs_exist_ok=True)


def copy_subject_directories(source_dir, output_dir, selected_subjects):
    """Copy subject directories for selected subjects."""
    source_path = Path(source_dir)
    output_path = Path(output_dir)
    
    for participant in selected_subjects:
        subject_id = participant['participant_id']
        source_subject_dir = source_path / subject_id
        dest_subject_dir = output_path / subject_id
        
        if source_subject_dir.exists():
            print(f"Copying subject directory: {subject_id}")
            shutil.copytree(source_subject_dir, dest_subject_dir, dirs_exist_ok=True)
        else:
            print(f"Warning: Subject directory not found: {subject_id}")


def create_subset_participants_tsv(selected_subjects, output_dir, original_fieldnames):
    """Create participants.tsv with only selected subjects."""
    output_path = Path(output_dir)
    participants_file = output_path / 'participants.tsv'
    
    # Remove the available_count field from fieldnames
    fieldnames = [f for f in original_fieldnames if f != 'available_count']
    
    print(f"Creating participants.tsv with {len(selected_subjects)} subjects")
    
    with open(participants_file, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, delimiter='\t')
        writer.writeheader()
        
        for participant in selected_subjects:
            # Create a copy without available_count
            row_data = {k: v for k, v in participant.items() if k != 'available_count'}
            writer.writerow(row_data)


def main():
    parser = argparse.ArgumentParser(
        description='Create subset BIDS dataset with subjects having most available data'
    )
    parser.add_argument('source_dataset', help='Path to source BIDS dataset')
    parser.add_argument('output_dataset', help='Path to output subset dataset')
    parser.add_argument('n_subjects', type=int, help='Number of subjects to select')
    parser.add_argument('--dry-run', action='store_true', 
                       help='Show selected subjects without creating dataset')
    
    args = parser.parse_args()
    
    # Validate inputs
    source_dir = Path(args.source_dataset)
    if not source_dir.exists():
        print(f"Error: Source dataset not found: {source_dir}")
        sys.exit(1)
    
    participants_file = source_dir / 'participants.tsv'
    if not participants_file.exists():
        print(f"Error: participants.tsv not found in: {source_dir}")
        sys.exit(1)
    
    # Read participants.tsv
    print(f"Reading participants.tsv from: {source_dir}")
    participants = read_participants_tsv(participants_file)
    print(f"Found {len(participants)} subjects in dataset")
    
    # Get original fieldnames for writing TSV later
    with open(participants_file, 'r', newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f, delimiter='\t')
        original_fieldnames = reader.fieldnames
    
    # Count available data per subject
    participants_with_counts, task_columns = count_available_data(participants)
    
    # Select top subjects
    if args.n_subjects > len(participants):
        print(f"Warning: Requested {args.n_subjects} subjects, but only {len(participants)} available")
        args.n_subjects = len(participants)
    
    selected_subjects = select_top_subjects(participants_with_counts, args.n_subjects)
    
    # Show statistics
    available_counts = [p['available_count'] for p in selected_subjects]
    print(f"\nAvailable data statistics:")
    print(f"Minimum available tasks: {min(available_counts)}")
    print(f"Maximum available tasks: {max(available_counts)}")
    print(f"Average available tasks: {sum(available_counts)/len(available_counts):.1f}")
    
    if args.dry_run:
        print("\nDry run complete. No files were copied.")
        return
    
    # Create subset dataset
    output_dir = args.output_dataset
    print(f"\nCreating subset dataset at: {output_dir}")
    
    # Copy root files (excluding subject directories and participants.tsv)
    print("\nCopying root-level files...")
    copy_root_files(source_dir, output_dir)
    
    # Copy selected subject directories
    print("\nCopying selected subject directories...")
    copy_subject_directories(source_dir, output_dir, selected_subjects)
    
    # Create new participants.tsv
    print("\nCreating subset participants.tsv...")
    create_subset_participants_tsv(selected_subjects, output_dir, original_fieldnames)
    
    print(f"\nSubset dataset created successfully at: {output_dir}")
    print(f"Selected {len(selected_subjects)} subjects with most available data")


if __name__ == "__main__":
    main() 