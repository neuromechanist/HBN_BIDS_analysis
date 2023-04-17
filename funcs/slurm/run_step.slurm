#!/bin/bash
#SBATCH -p shared
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH -c 16
#SBATCH --mem=32G
#SBATCH -t 02:00:00
#SBATCH -A csd403
#SBATCH -o /home/sshirazi/runlog/rpr_%x.out
#SBATCH -e /home/sshirazi/runlog/rpr_%x.err

# echo $1
cd /home/sshirazi/_git/HBN_BIDS_analysis
module load cpu slurm gcc openmpi matlab
export MV2_ENABLE_AFFINITY=0
# matlab -nodisplay -r "step3_incr_dipfit_eval('$i', 1, 'linux', 'expanse', 12)"

# if you just run ICA on expanse
matlab -nodisplay -r "step2_incr_rej('$i', 0, 1, 0, 'linux', 'expanse', 0, 0);"

