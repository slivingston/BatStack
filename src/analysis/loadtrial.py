#!/usr/bin/env python
"""
Load and display Array data file, or raw SD-card-dumped disparate dumps.

...the latter is "raw" in the sense that it is not in the standard
file container for Array data as described in the technical manual.

Internal notes: There are some internal constants that should either
be dynamically determined from the given data or set by the User.


Scott Livingston  <slivingston@caltech.edu>
Jun, Sep-Oct 2010.
"""


import sys
import math

import numpy as np
import matplotlib as mpl
import matplotlib.pyplot as plt

import batstack


Ts = 3.75e-6

if ('-h' in sys.argv) or (len(sys.argv) != 2 and len(sys.argv) < 4) or not (len(sys.argv)%2 == 0 or (len(sys.argv) >= 7 and sys.argv[-3] == '-t')):
    print 'Usage: %s $Array-data-file\nUsage: %s $basename ($addr $trial)^? [-t $t_start $t_stop]' % (sys.argv[0], sys.argv[0])
    exit(1)

# Handle case of reading an Array data file (rather than disparate SD-card-dumped shit).
if len(sys.argv) == 2:
    bsaf = batstack.BSArrayFile(sys.argv[1])
    bsaf.printparams()
    if len(bsaf.data) < 1:
        print 'Error reading Array data file (or its empty).'
        exit(-1)
    x = bsaf.export_chandata()
    t_win = []
else:
    bname = sys.argv[1]
    bs_id = []
    trial_num = []
    len_argv = len(sys.argv)
    if len_argv%2 == 1: # Extract desired time range?
        t_win = [float(sys.argv[-2]), float(sys.argv[-1])]
        len_argv -= 3
    else:
        t_win = [] # Empty indicates use all available
    for k in range(2, len_argv, 2): # Read Stack IDs and trial numbers
        bs_id.append( int(sys.argv[k]) )
        trial_num.append( int(sys.argv[k+1]) )

    x = batstack.raw_arr_read(bname, bs_id, trial_num)
    if len(x) == 0:
        print 'Error occurred while loading trial data.'
        exit(-1)
    
t = [k*Ts for k in range(-len(x[0])+1,1)]
    
if len(t_win) == 2:
    win_ind = batstack.find_intv(t, t_win[0], t_win[1])
    if len(win_ind) == 2:
        t = t[win_ind[0]:(win_ind[1]+1)]
        for k in range(len(x)):
            x[k] = x[k][win_ind[0]:(win_ind[1]+1)]

num_cols = int(math.ceil(len(x)/4.))
ax1 = plt.subplot(4,num_cols,1)
for ind in range(len(x)):
    plt.subplot(4,num_cols,1+ind, sharex=ax1)
    plt.plot(t, x[ind])
    plt.xlim([t[0], t[-1]])
    plt.grid()
plt.show()
