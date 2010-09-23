#!/usr/bin/env python
"""
Load and display raw BatStack array data.

..."raw" in the sense that it is not in the standard file container
for Array data as described in the technical manual.

Internal notes: There are some internal constants that should either
be dynamically determined from the given data or set by the User.


Scott Livingston  <slivingston@caltech.edu>
Jun, Sep 2010.
"""


import sys
import math
import struct

import numpy as np
import matplotlib as mpl
import matplotlib.pyplot as plt


def raw_arr_read( bname, bs_id, trial_num ):
    """Read raw wideband array data file, of form *_*_trial*.bin

On success, returns length len(bs_id) list, where each element has
data in an ndarray (i.e. the type by NumPy) for that channel for that
BatStack; note that ordering matches that of given bs_id list.

Otherwise (i.e., on error), returns an empty list.
"""
    trial_len = 1**20 # Length (in words) per channel per trial
    x = []
    num_chans = 0
    for bid in bs_id:
        fname = bname + '_' + str(bid).zfill(2) + '_trial' + str(trial_num[num_chans/4]).zfill(2) + '.bin'
        result = np.fromfile(fname, dtype='uint16')
        for k in range(4):
            x.append(result[range(k, len(result), 4)])
        num_chans += 4
        continue
    return x

def find_intv( t, t_min, t_max ):
    """Binary search for indices in given time array.

On success, returns a two element list corresponding to indices in t.
On failure, returns empty.
"""
    win_min  = len(t)/2
    last_ind = None
    step_size = len(t)/4
    while win_min != last_ind:
        last_ind = win_min
        if t[win_min] < t_min:
            win_min += step_size
        elif t[win_min] > t_min:
            win_min -= step_size
        else:
            break
        step_size /= 2
    win_max  = len(t)/2
    last_ind = None
    step_size = len(t)/4
    while win_max != last_ind:
        last_ind = win_max
        if t[win_max] < t_max:
            win_max += step_size
        elif t[win_max] > t_max:
            win_max -= step_size
        else:
            break
        step_size /= 2
    return [win_min, win_max]


if __name__ == "__main__": # Called as stand-alone?
    Ts = 3.75e-6

    if ('-h' in sys.argv) or len(sys.argv) < 4 or not (len(sys.argv)%2 == 0 or (len(sys.argv) >= 7 and sys.argv[-3] == '-t')):
        print 'Usage: %s $basename ($addr $trial)^? [-t $t_start $t_stop]' % sys.argv[0]
        exit(1)
    bname = sys.argv[1]
    bs_id = []
    trial_num = []
    len_argv = len(sys.argv)
    if len_argv%2 == 1: # Extract desired time range?
        t_win = [float(sys.argv[-2]), float(sys.argv[-1])]
        len_argv -= 3
    else:
        t_win = [] # Empty indicates use all available
    for k in range(2,len_argv,2): # Read Stack IDs and trial numbers
        bs_id.append( int(sys.argv[k]) )
        trial_num.append( int(sys.argv[k+1]) )

    x = raw_arr_read( bname, bs_id, trial_num )
    if len(x) == 0:
        print 'Error occurred while loading trial data.'
        exit(-1)

    #for k in range(len(x)): # Remove mean
    #    xk_mean = np.mean(x[k])
    #    x[k] = [j-xk_mean for j in x[k]]
    
    t = [k*Ts for k in range(-len(x[0])+1,1)]
    
    if len(t_win) == 2:
        win_ind = find_intv(t, t_win[0], t_win[1])
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
    plt.show()

#(Pxx, freqs, bins, im) = specgram( x[ind][intv[0]:intv[1]], NFFT=128, Fs=1/Ts, noverlap=120 )
