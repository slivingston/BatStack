#!/bin/sh

DIR=/Users/scott/exp_data_Batlab_landing_collab/wideband_array/PR46

for f in $DIR/*; do
    f_abbr=`echo $f | cut -d / -f 7`
    echo Processing $f_abbr ...
    ./update12.py $f v2-$f_abbr
done
