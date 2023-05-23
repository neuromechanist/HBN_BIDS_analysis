#!/bin/bash
#SBATCH -p shared
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH -c 64
#SBATCH --mem=124G
#SBATCH -t 02:00:00
#SBATCH -A csd403
#SBATCH -o /home/sshirazi/runlog/s3_%x.out
#SBATCH -e /home/sshirazi/runlog/s3_%x.err

# echo $i
cd /home/sshirazi/_git/HBN_BIDS_analysis
module load cpu slurm matlab/2022b
export MV2_ENABLE_AFFINITY=0

# step 3
matlab -nodisplay -r "step3_incr_dipfit_eval('$i', {'everyEEG','videoEEG'}, 1, 'linux', 'expanse', 12)"

