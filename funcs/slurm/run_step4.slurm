#!/bin/bash
#SBATCH -p shared
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH -c 8
#SBATCH --mem=14G
#SBATCH -t 00:30:00
#SBATCH -A csd403
#SBATCH -o /home/sshirazi/runlog/s4_%x.out
#SBATCH -e /home/sshirazi/runlog/s4_%x.err

# echo $i
cd /home/sshirazi/_git/HBN_BIDS_analysis
module load cpu slurm matlab/2022b
export MV2_ENABLE_AFFINITY=0

# step 4
matlab -nodisplay -r "step4_perform_multiple_amica('$i', [], [], [], [], 1, 1, 3, 64, 512, 3)"
