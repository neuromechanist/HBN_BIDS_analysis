#!/bin/bash
for i in 'NDARFW038ZNE'
do
# echo $i  # sanity check
sbatch -J $i --export=ALL,i=$i /home/sshirazi/_git/HBN_BIDS_analysis/funcs/slurm/preprcss_to-step2.slurm
done
