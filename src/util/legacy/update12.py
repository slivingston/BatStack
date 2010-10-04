#!/usr/bin/env python
"""
Update an Array data file from version 1 to version 2.

Scott Livingston  <slivingston@caltech.edu>
Oct 2010.
"""

import sys
import batstack


if len(sys.argv) < 2 or len(sys.argv) > 3:
    print 'Usage: %s origfile.bin [newfile.bin]' % sys.argv[0]
    exit(1)

print 'Reading %s...' % sys.argv[1]
bsaf = batstack.BSArrayFile()
if bsaf.readfile(sys.argv[1]) is False:
    print 'Error: could not read Array data file, %s' % sys.argv[1]
    exit(-1)
if bsaf.version != 1:
    print 'Given file uses spec version %d (not 1)!' % bsaf.version
    exit(-1)

if len(sys.argv) == 3:
    out_fname = sys.argv[2]
else:
    out_fname = 'v2-' + sys.argv[1]

if out_fname == sys.argv[1]:
    choice = raw_input('Overwrite existing file, '+sys.argv[1]+'? ([n]/y) ')
    if len(choice) > 0 and (choice[0] == 'y'):
        print 'Allowing overwrite...'
        prevent_overwrite = False
    else:
        print 'Disallowing overwrite...'
        prevent_overwrite = True
else:
    prevent_overwrite = True

print 'Writing %s...' % out_fname
bsaf.version = 2
if bsaf.writefile(out_fname, prevent_overwrite=prevent_overwrite) is False:
    print 'Error occurred while writing file.'
    exit(-1)
