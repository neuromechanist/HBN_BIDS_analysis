#!/bin/bash
#SBATCH -p shared
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH -c 8
#SBATCH --mem=15G
#SBATCH -t 04:00:00
#SBATCH -A csd403
#SBATCH -o /home/sshirazi/runlog/s1_%x.out
#SBATCH -e /home/sshirazi/runlog/s1_%x.err

# echo $i
cd /home/sshirazi/_git/HBN_BIDS_analysis
module load cpu slurm matlab/2022b
export MV2_ENABLE_AFFINITY=0

# step 4
# matlab -nodisplay -r "step4_perform_multiple_amica('$i', [], [], [], [], 1, 1, 3)"

# step 3
# matlab -nodisplay -r "step3_incr_dipfit_eval('$i', 1, 'linux', 'expanse', 12)"

# step2
# if you just run ICA on expanse
# matlab -nodisplay -r "step2_incr_rej('$i', 0, 1, 0, 'linux', 'expanse', 0, 1);"


# step1 complete preprocessing
matlab -nodisplay -r "step1_intial_filtering_concat('$i', 'linux', 'expanse', 1, 0);"
matlab -nodisplay -r "step2_incr_rej('$i', {'everyEEG', 'videoEEG'}, 1, 1, 1, 'linux', 'expanse', 0, 0)";
