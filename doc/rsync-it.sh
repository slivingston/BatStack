#!/bin/sh
#
# copy build of doc to private (temporary) location,
# http://www.cds.caltech.edu/~slivings/off-site/BatStack_man.pdf

rsync -vz BatStack_man.pdf slivings@www.cds.caltech.edu:/home/slivings/public_html/off-site/
