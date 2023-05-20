#!/bin/bash
#SBATCH -p shared
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH -c 4
#SBATCH --mem=6G
#SBATCH -t 00:30:00
#SBATCH -A csd403
#SBATCH -o /home/sshirazi/runlog/incrICA_%x.out
#SBATCH -e /home/sshirazi/runlog/incrICA_%x.err

# echo $i
cd /home/sshirazi/_git/HBN_BIDS_analysis
module load cpu slurm matlab/2022b
export MV2_ENABLE_AFFINITY=0

# step2
# if you just run ICA on expanse
matlab -nodisplay -r "step2_incr_rej('$i', {'everyEEG', 'videoEEG'}, 0, 0, 1, 'linux', 'expanse', 0, 0);"

