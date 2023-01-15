#!/bin/bash
for i in 'NDARFX710UZA'
do
# echo $i  # sanity check
sbatch -J $i ../slurm/preprcss_to-step2.slurm
done
