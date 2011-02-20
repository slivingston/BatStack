#!/usr/bin/env python
"""
Print header/parameters from a BatStack Array data file.

Scott Livingston  <slivingston@caltech.edu>
Feb 2011.
"""

import sys
import batstack

if len(sys.argv) != 2:
    print "Usage: bsinfo.py $file"
    exit(1)
    
bsaf = batstack.BSArrayFile()
bsaf.print_hdr(sys.argv[1])
# Errors are reported to stdout from within print_hdr class method
#if not bsaf.print_hdr(sys.argv[1]):
    #print "Error: failed to read %s" % sys.argv[1]
