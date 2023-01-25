#!/bin/bash
for i in 'NDARGC170UK2'
do
# echo $i  # sanity check
sbatch -J $i --export=ALL,i=$i /home/sshirazi/_git/HBN_BIDS_analysis/funcs/slurm/preprcss_to-step2.slurm
done
