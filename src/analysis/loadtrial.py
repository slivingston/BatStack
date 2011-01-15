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
Jun, Sep-Oct 2010; Jan 2011.
"""


from optparse import OptionParser # Deprecated since Python v2.7, but for folks using 2.5 or 2.6...
import sys
import math
from os import getcwd

import numpy as np
import matplotlib as mpl
import matplotlib.pyplot as plt

import batstack


# Globals to-be-made-internal-or-parametric at some point
Ts = 3.75e-6

parser = OptionParser()
parser.add_option("-l", action="store_true", dest="verbose_title", default=False,
                  help="verbose title and plot labeling")
parser.add_option("-s", action="store_true", dest="mk_specgram", default=False,
                  help="print spectrogram (rather than the default, time waveform)")
parser.add_option("-t", nargs=2, metavar="t0 T", dest="t_win", default=None,
                  help="read time window of t0 to T; (default is entire trial)")
parser.add_option("-f", metavar="FILE", dest="bsaf_filename", default=None)
parser.add_option("-r", metavar="BASENAME,ADDR0,TRIAL0,ADDR1,TRIAL1,...", dest="raw_trial_list", default=None)
parser.add_option("-c", metavar="CH0,CH1,...", dest="chan_list", default=None,
                  help="only display specified channels")
parser.add_option("-n", "--no-zero", action="store_true", dest="hide_zero_channels", default=False,
                  help="hide zero channels (i.e. those without data)")

(options, args) = parser.parse_args()
if options.bsaf_filename and options.raw_trial_list:
    parser.error("either specify an Array data file to read,\nor (legacy) a basename and list of address,trial pairs.")
if not options.bsaf_filename and not options.raw_trial_list:
    parser.error("a data source must be provided (try -f or -r options...).")

# Convert time window to float, if given
if options.t_win is not None:
    try:
        t_win = [float(options.t_win[0]), float(options.t_win[1])]
        if t_win[1] < t_win[0]:
            print "Warning: given time range invalid; using whole trial."
            t_win = []
    except ValueError:
        print "Warning: given time range invalid; using whole trial."
        t_win = []
else:
    t_win = []
    
# Convert channel list to integers and check syntax
if options.chan_list is not None:
    chan_list = []
    print options.chan_list.split(',')
    for k in options.chan_list.split(','):
        try:
            chan_list.append(int(k))
        except ValueError:
            print "Bad channel number: %s" % k
            exit(-1)
        if chan_list[-1] < 1:
            print "Bad channel number (not positive): %s" % k
            exit(-1)
else:
    chan_list = [] # empty indicates ALL channels

# Handle case of reading an Array data file (rather than disparate SD-card-dumped shit).
if options.bsaf_filename:
    using_Arr_datafile = True # To help with verbose_title
    bsaf = batstack.BSArrayFile(options.bsaf_filename)
    bsaf.printparams()
    if len(bsaf.data) < 1:
        print 'Error reading Array data file (or its empty).'
        exit(-1)
    x = bsaf.export_chandata()
    nz_chans = bsaf.getnz() # Distinguish nonzero channels.
else: # Legacy
    using_Arr_datafile = False # To help with verbose_title
    raw_trial_list = options.raw_trial_list.split(',')
    bname = raw_trial_list[0]
    bs_id = []
    trial_num = []
    for k in range(1, len(raw_trial_list), 2): # Read Stack IDs and trial numbers
        bs_id.append( int(raw_trial_list[k]) )
        trial_num.append( int(raw_trial_list[k+1]) )

    x = batstack.raw_arr_read(bname, bs_id, trial_num)
    if len(x) == 0:
        print 'Error occurred while loading trial data.'
        exit(-1)
    nz_chans = range(len(x)+1)[1:]

# Remove any 
    
# Trim away unwanted channels, if any, and handle labeling
# This routine is INEFFICIENT but decent for now.
if len(chan_list) > 0:
    chan_list.sort()
    for ind in range(len(chan_list)):
        if chan_list[ind] > len(x):
            print "Warning: requested channel outside range (%d): %d" % (len(x), chan_list[ind])
            del chan_list[ind:]
            break
    x_trimmed = []
    for k in chan_list:
        x_trimmed.append(x[k-1])
    x = x_trimmed
else: # Default to all available channels.
    chan_list = range(1,len(x)+1)
    
# If requested, trim zero channels, i.e. those without data
if options.hide_zero_channels:
    x_trimmed = []
    chan_list_trimmed = []
    for k in nz_chans:
        if k in chan_list:
            ind = chan_list.index(k)
            x_trimmed.append(x[ind])
            chan_list_trimmed.append(k)
    x = x_trimmed
    chan_list = chan_list_trimmed
    if len(chan_list) == 0:
        print "No channels to display."
        exit(0)
    
t = [k*Ts for k in range(-len(x[0])+1,1)]
    
if len(t_win) == 2:
    win_ind = batstack.find_intv(t, t_win[0], t_win[1])
    if len(win_ind) == 2:
        t = t[win_ind[0]:(win_ind[1]+1)]
        for k in range(len(x)):
            x[k] = x[k][win_ind[0]:(win_ind[1]+1)]

num_cols = int(math.ceil(len(x)/4.))
num_rows = len(x)/num_cols
ax1 = plt.subplot(num_rows,num_cols,1)
for ind in range(len(x)):
    ax = plt.subplot(num_rows,num_cols,1+ind, sharex=ax1)
    for label in ax.xaxis.get_ticklabels():
        label.set_fontsize(8)
    for label in ax.yaxis.get_ticklabels():
        label.set_fontsize(8)
    if options.mk_specgram:
        if chan_list[ind] in nz_chans:
            plt.specgram(x[ind]-np.mean(x[ind]), xextent=(t[0], t[-1]),
                         NFFT=128,
                         noverlap=120,
                         Fs=1./Ts)
    else:
        plt.plot(t, x[ind])
    plt.xlim([t[0], t[-1]])
    if options.mk_specgram and chan_list[ind] not in nz_chans:
        pass
    else:
        plt.grid()
    if options.verbose_title:
        if using_Arr_datafile:
            plt.title('ch '+str(chan_list[ind]), fontsize=10)
        else:
            plt.title(str(bs_id[ind/4])+':'+str((ind%4)+1)+' (trial '+str(trial_num[ind/4])+')', fontsize=10)
if options.verbose_title:
    if options.mk_specgram:
        plt.suptitle(getcwd() + ' \n' + ' '.join(sys.argv[1:]) + '  (Subplot color axes are not equally scaled!)')
    else:
        plt.suptitle(getcwd() + ' \n' + ' '.join(sys.argv[1:]))
plt.show()
