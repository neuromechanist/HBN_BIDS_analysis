#!/bin/bash
#SBATCH -p shared
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=32
#SBATCH --mem=64G
#SBATCH -t 01:30:00
#SBATCH -A csd403
#SBATCH -o /home/sshirazi/runlog/%x.out
#SBATCH -e /home/sshirazi/runlog/%x.err

# echo $i
cd /home/sshirazi/_git/HBN_BIDS_analysis
module load matlab
matlab -nodisplay -r "step1_intial_filtering_concat('$i', 'linux', 'expanse', 1, 30);"
matlab -nodisplay -r "step2_incr_rej('$i', 1, 1, linux', 'expanse', 30);"
