#!/bin/bash
# This should be placed at the root of data storage where you have subject folders
for i in {1..40}
do
# echo(./NDARAA075AMK/ICA/incr$i/NDARAA075AMK_everyEEG_incr_${i}_linux.param)
./amica15mac $1/ICA/incr$i/$1_everyEEG_incr_${i}_linux.param
done

