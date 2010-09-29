#!/usr/bin/env python
"""
A collection of handy functions for the BatStack project.

Largely unsorted, but each function should have a decent docstring.


Scott Livingston  <slivingston@caltech.edu>
Sep 2010.
"""


import sys


def read_chanmap( fname ):
    """Read plaintext channel map file.

Supports either manual or automatic addressing. This is set by
considering the number of elements in the first row of the file. If
there are 5, then we assume manual and use the first element of every
row as the address. If there are 4, then we assume automatic and begin
with Stack of first row having address 1, second row 2, and so on.

Note that, in manual mode, we assume addresses are given in
hexadecimal format; e.g., 0x0a is read as 10 (base 10). The '0x'
prefix is optional.

Returns a dictionary with keys corresponding to Stack addresses and
values being lists (of length 4, always) where index in list
corresponds to local channel number and actual value is global
(i.e. system-wide for your Array implementation) channel.

On error, an empty dictionary is returned.
"""
    try:
        f = open(fname, 'r')
    except:
        print 'Error: could not open %s for reading.' % fname
        return {}
    line = f.readline()
    tok = line.split()
    if len(tok) == 5:
        man_addr_flag = True
    elif len(tok) == 4:
        man_addr_flag = False
        current_addr = 1
    else:
        print 'Error: file looks ill-formed.'
        return {}
    di = {}
    if man_addr_flag:
        di[int(tok[0], 16)] = [int(x) for x in tok[1:]]
    else:
        di[current_addr] = [int(x) for x in tok]
        current_addr += 1
    for line in f:
        tok = line.split()
        if man_addr_flag:
            di[int(tok[0], 16)] = [int(x) for x in tok[1:]]
        else:
            di[current_addr] = [int(x) for x in tok]
            current_addr += 1
    f.close()
    return di


# For use at the command-line,
if __name__ == "__main__":
    di = read_chanmap( sys.argv[1] )
    print di
