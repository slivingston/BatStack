#!/usr/bin/env python
#
#
# Scott Livingston  <slivingston@caltech.edu>
# June 2010.

import sys
import math
from pylab import *


def raw_arr_read( bname, bs_id, trial_num ):
    """Read raw wideband array data file, of form *_*_trial*.bin

On success, returns length len(bs_id) list, where each element has
data for that channel for that BatStack; note that ordering matches
that of given bs_id list.

Otherwise (i.e., on error), returns an empty list."""
    trial_len = 2**20 # Length (in words) per channel per trial
    x = []
    num_chans = 0
    for bid in bs_id:
        x.append( range(trial_len) )
        x.append( range(trial_len) )
        x.append( range(trial_len) )
        x.append( range(trial_len) )
        fname = bname + '_' + str(bid).zfill(2) + '_trial' + str(trial_num[num_chans/4]).zfill(2) + '.bin'
        try:
            fd = open( fname, 'r' )
        except:
            print 'Error: failed to load file %s' % fname
            return [] # Return empty list on error
        try:
            print 'Reading %s ...' % fname
            x_raw = fd.read() # Read all at once, or bust
            fd.close()
        except:
            fd.close()
            return []
        for k in range(trial_len): # Read as uint16, little-endian
            for offset in range(4):
                x[num_chans+offset][k] = ord(x_raw[k*8+offset*2]) + (ord(x_raw[k*8+offset*2+1])<<8)
        num_chans += 4
    return x


if __name__ == "__main__": # Called as stand-alone?
    Ts = 3.75e-6

    if len(sys.argv) < 4 or len(sys.argv)%2 == 1:
        print 'Usage: %s $basename ($addr $trial)^? [-t $t_start $t_stop]' % sys.argv[0]
        exit(1)
    bname = sys.argv[1]
    bs_id = []
    trial_num = []
    for k in range(2,len(sys.argv),2):
        bs_id.append( int(sys.argv[k]) )
        trial_num.append( int(sys.argv[k+1]) )
    #if len(sys.argv) == 6:
    #    intv = [int(float(sys.argv[4])/Ts), int(float(sys.argv[5])/Ts)]
    #else:
    #    intv = [0, int(.2/Ts)]

    x = raw_arr_read( bname, bs_id, trial_num )
    if len(x) == 0:
        print 'Error occurred while loading trial data.'
        exit(-1)
    for k in range(len(x)): # Remove mean
        xk_mean = mean(x[k])
        x[k] = [j-xk_mean for j in x[k]]
    
    t = [k*Ts for k in range(-len(x[0])+1,1)]
    num_cols = int(math.ceil(len(x)/4.))
    ax1 = subplot(4,num_cols,1)
    for ind in range(len(x)):
        subplot(4,num_cols,1+ind, sharex=ax1)
        plot(t, x[ind])
    show()

#(Pxx, freqs, bins, im) = specgram( x[ind][intv[0]:intv[1]], NFFT=128, Fs=1/Ts, noverlap=120 )
