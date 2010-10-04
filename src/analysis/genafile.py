#!/usr/bin/env python
"""
Generate an array data file, conforming to standard format.

Confer the BatStack reference manual for file specifications.  This
utility script provides a way to convert a collection of disparate
raw-BatStack-SD-card-extracted data dumps (as gotten via dumpsd; look
under src/util/dumpsd in the sourcetree) into a conformant Array data
file, using a plaintext ``parameters file.''  See documentation for

batstack.BSArrayFile.parse_paramfile

for more details about the ``params'' file.


Scott Livingston  <slivingston@caltech.edu>
Oct 2010.
"""


import sys
from datetime import date

import batstack


if __name__ == '__main__':
    Ts = 3.75e-6

    if len(sys.argv) < 5 or ('-h' in sys.argv):
        # Note that version number is not an option; we force version 2!
        # (This will change eventually, perhaps.)
        print 'Usage: %s $chanmap_file $basename ($addr $trial)^? [-n $num_channels] [-f $params_file] [-t $trial_number] [-d $YYYY $MM $DD] [-m $notes ...]' % sys.argv[0]
        exit(1)

    chanmap_fname = sys.argv[1]
    bname = sys.argv[2]
    bs_id = []
    trial_num = []

    # Setting these to None simplifies checking whether they were
    # defined in the command-line arguments later.
    num_mics = None
    params_fname = None
    saved_trial_num = None
    notes = None
    d = None
    
    # Parse command-line arguments (this might be easier using GNU Readline)
    remaining_indices = range(3, len(sys.argv))
    del_list = []
    k = 0
    while k < len(remaining_indices)-1:
        if sys.argv[remaining_indices[k]][:2] == '-n':
            # Number of channels
            num_mics = int(sys.argv[remaining_indices[k+1]])
            if num_mics < 1:
                print 'Number of microphones must be positive.'
                exit(-1)
            del_list += [k, k+1]
            k += 2
        elif sys.argv[remaining_indices[k]][:2] == '-d':
            # Date string
            try:
                d = date(int(sys.argv[remaining_indices[k+1]]),
                         int(sys.argv[remaining_indices[k+2]]),
                         int(sys.argv[remaining_indices[k+3]]))
            except:
                print 'Error parsing given date.'
                exit(-1)
            del_list += [k, k+1, k+2, k+3]
            k += 4
        elif sys.argv[remaining_indices[k]][:2] == '-f':
            # Params file
            params_fname = sys.argv[remaining_indices[k+1]]
            del_list += [k, k+1]
            k += 2
        elif sys.argv[remaining_indices[k]][:2] == '-t':
            # Trial number for this Array data file
            saved_trial_num = int(sys.argv[remaining_indices[k+1]])
            if saved_trial_num < 0:
                print 'Trial number for this Array data file must be nonnegative.'
                exit(-1)
            del_list += [k, k+1]
            k += 2
        elif sys.argv[remaining_indices[k]][:2] == '-m':
            # Notes string; this kills further argument parsing
            notes = ' '.join(sys.argv[remaining_indices[k+1]:])
            del_list += range(k, len(remaining_indices))
            k = len(remaining_indices)
        else:
            k += 1

    # This is an ugly way to remove dead indices (of command-line
    # arguments already processed). Needs to be refactored.
    old_remaining_indices = remaining_indices
    remaining_indices = []
    for k in range(len(old_remaining_indices)):
        if k not in del_list:
            remaining_indices.append(old_remaining_indices[k])

    # Read Stack IDs and trial numbers
    for k in range(remaining_indices[0], remaining_indices[-1], 2):
        bs_id.append( int(sys.argv[k]) )
        trial_num.append( int(sys.argv[k+1]) )

    # Read channel map file
    chanmap = batstack.read_chanmap(chanmap_fname)
    if len(chanmap) < 1:
        print 'Error: absent or empty channel map file, ' + chanmap_fname
        exit(-1)

    # Read in disparate channel data
    print 'Reading trial data...'
    x = batstack.raw_arr_read(bname, bs_id, trial_num)
    if len(x) == 0:
        print 'Error occurred while loading trial data.'
        exit(-1)

    # Instantiate and populate BSArrayFile
    #
    # N.B., we manipulate relevant (internal) attributes of this
    # BSArrayFile object.  This is poor practice but a decent solution
    # for now.  Perhaps some accessor-style methods would be better?
    bsaf = batstack.BSArrayFile(param_fname=params_fname)
    if num_mics is not None:
        bsaf.num_mics = num_mics
    if saved_trial_num is not None:
        bsaf.trial_number = saved_trial_num
    if notes is not None:
        bsaf.notes = notes
    if d is not None:
        bsaf.recording_date = d

    for (k, v) in chanmap.items():
        try:
            bs_addr_ind = bs_id.index(k)
        except ValueError:
            print 'Warning: could not find data for Stack addr 0x%02X' % k
            continue
        for local_ind in range(len(v)):
            bsaf.data[v[local_ind]] = x[bs_addr_ind*4+local_ind] # Need to copy() here?

    bsaf.printparams() # Helpful for debugging.
    print 'Writing result...'
    bsaf.writefile('test.bin')
