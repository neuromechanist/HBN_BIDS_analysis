#!/bin/bash
#SBATCH -p shared
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH -c 32
#SBATCH --mem=64G
#SBATCH -t 02:00:00
#SBATCH -A csd403
#SBATCH -o /home/sshirazi/runlog/%x.out
#SBATCH -e /home/sshirazi/runlog/%x.err

# echo $1
cd /home/sshirazi/_git/HBN_BIDS_analysis
module load cpu slurm gcc openmpi matlab
export MV2_ENABLE_AFFINITY=0
#matlab -nodisplay -r "step1_intial_filtering_concat('$i', 'linux', 'expanse', 1, 30);"
#matlab -nodisplay -r "step2_incr_rej('$i', 1, 1, 1, 'linux', 'expanse', 30, 0);"

# if you just run ICA on expanse
# first making sure that the increment folders are as intended.
sh funcs/slurm/rename_dirs.sh "/home/sshirazi/HBN_EEG/$i/ICA/"
matlab -nodisplay -r "step2_incr_rej('$i', 0, 0, 1, 'linux', 'expanse', 0, 1);"

