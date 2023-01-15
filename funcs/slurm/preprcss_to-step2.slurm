#!/bin/bash
#SBATCH -p shared
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=32
#SBATCH --mem=64G
#SBATCH -t 01:30:00
#SBATCH -A csd403
#SBATCH -o /home/sshirazi/runlog/%x.out
#SBATCH -e /home/sshirazi/runlog/%x.err
#SBATCH --export=ALL

load module matlab
matlab -nodisplay -r 'step1_intial_filtering_concat(%x, "expanse", 1, 30); end'
maltab -nodisplay -r 'step2_incr_rej(%x, 1, 1, "expanse",  30); end'
