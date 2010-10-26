#!/usr/bin/env python
"""
Load and display Array data file, or raw SD-card-dumped disparate dumps.

...the latter is "raw" in the sense that it is not in the standard
file container for Array data as described in the technical manual.

Use the command-line flag -l to get a figure with an informative title
(at the possible cost of screen real estate).

Internal notes: There are some internal constants that should either
be dynamically determined from the given data or set by the User.


Scott Livingston  <slivingston@caltech.edu>
Jun, Sep-Oct 2010.
"""


import sys
import math
from os import getcwd

import numpy as np
import matplotlib as mpl
import matplotlib.pyplot as plt

import batstack


Ts = 3.75e-6

# Before everything, look for and extract -l and -s arguments
try:
    ind = sys.argv.index('-l')
    verbose_title = True
    sys.argv.pop(ind) # Pull it out
except ValueError:
    verbose_title = False
try:
    ind = sys.argv.index('-s')
    mk_specgram = True
    sys.argv.pop(ind) # Pull it out
except ValueError:
    mk_specgram = False

# Now usual command-line argument processing
if ('-h' in sys.argv) or (len(sys.argv) != 2 and len(sys.argv) < 4) or not (len(sys.argv)%2 == 0 or (len(sys.argv) >= 7 and sys.argv[-3] == '-t')):
    print 'Usage: %s $Array-data-file [-l] [-s]\nUsage: %s $basename ($addr $trial)^? [-t $t_start $t_stop] [-l] [-s]' % (sys.argv[0], sys.argv[0])
    exit(1)

# Handle case of reading an Array data file (rather than disparate SD-card-dumped shit).
if len(sys.argv) == 2:
    using_Arr_datafile = True # To help with verbose_title
    bsaf = batstack.BSArrayFile(sys.argv[1])
    bsaf.printparams()
    if len(bsaf.data) < 1:
        print 'Error reading Array data file (or its empty).'
        exit(-1)
    x = bsaf.export_chandata()
    t_win = []
else:
    using_Arr_datafile = False # To help with verbose_title
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
    ax = plt.subplot(4,num_cols,1+ind, sharex=ax1)
    for label in ax.xaxis.get_ticklabels():
        label.set_fontsize(8)
    for label in ax.yaxis.get_ticklabels():
        label.set_fontsize(8)
    if mk_specgram:
        plt.specgram(x[ind]-np.mean(x[ind]), xextent=(t[0], t[-1]),
                     NFFT=128,
                     noverlap=120,
                     Fs=1./Ts)
    else:
        plt.plot(t, x[ind])
    plt.xlim([t[0], t[-1]])
    #plt.grid()
    if verbose_title:
        if using_Arr_datafile:
            plt.title('ch '+str(ind+1), fontsize=10)
        else:
            plt.title(str(bs_id[ind/4])+':'+str((ind%4)+1)+' (trial '+str(trial_num[ind/4])+')', fontsize=10)
if verbose_title:
    plt.suptitle(getcwd() + ' \n' + ' '.join(sys.argv[1:]) + '  (Subplot color axes are not equally scaled!)')
plt.show()
