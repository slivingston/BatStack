#!/bin/sh
#
# For stripping the ``v2-'' prefix from all *.bin files in current
# directory; ``v2-'' is prepended by update12.py by default.
#
# Scott Livingston
# Oct 2010.

for f in *.bin; do
    f_name=`echo $f| cut -d - -f 2`
    mv -v $f $f_name
done
