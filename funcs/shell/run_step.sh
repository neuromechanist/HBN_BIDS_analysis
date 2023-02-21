#!/bin/bash
for i in $(cat subjs_to_analyze.txt); do
# echo $i  # sanity check
sbatch -J $i --export=ALL,i=$i /home/sshirazi/_git/HBN_BIDS_analysis/funcs/slurm/run_step3.slurm
sleep 3m
done
