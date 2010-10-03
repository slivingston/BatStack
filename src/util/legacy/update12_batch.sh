#!/bin/sh
#
# Apply update12.py (legacy support) tool in batch. You might need to
# change the field number passed to ``cut'' (the goal is to strip full
# path to get just the local name) and DIR to your target directory.
#
# Scott Livingston
# Oct 2010.

DIR=/Users/scott/exp_data_Batlab_landing_collab/wideband_array/PR47

for f in $DIR/*; do
    f_abbr=`echo $f | cut -d / -f 7`
    echo Processing $f_abbr ...
    ./update12.py $f $f_abbr
done
