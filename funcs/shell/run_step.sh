#!/bin/bash
for i in $(cat leftout_subjs_step3.txt); do
# echo $i  # sanity check

# in case that this run step is for re-processing of step3, there is a need to rename some folders.
sh rename_incr.sh "/home/sshirazi/HBN_EEG/$i/ICA/"

sbatch -J $i --export=ALL,i=$i /home/sshirazi/_git/HBN_BIDS_analysis/funcs/slurm/run_step.slurm
sleep 3m
done
