#!/usr/bin/env python
"""
A collection of handy stuff for the BatStack project.

Largely unsorted, but each function should have a decent docstring.


Scott Livingston  <slivingston@caltech.edu>
Sep-Oct 2010.
"""


import sys
import struct
from datetime import date

import numpy as np


def gendate_explicit(year, month, day):
    """Generate a 16-bit date conforming to BatStack header format.

Accepts year, month and day as separate integers, hence does not
depend on datetime module.

Returns result as an unsigned short (i.e. u16) value.
On error, returns None.
"""
    if year < 1970 or month < 0 or month > 12 or day < 1 or day > 31:
        return None
    result = day&0x1F
    result |= (month&0xF) << 5
    result |= ((year-1970)&0x7F) << 9
    return result

def gendate( d=date.today() ):
    """Generate a 16-bit date conforming to BatStack header format.

Accepts date as an instance of class date (from datetime module).
Default value (i.e. if no argument given), today is used.

Returns result as an unsigned short (i.e. u16) value.
"""
    result = d.day&0x1F
    result |= (d.month&0xF) << 5
    result |= ((d.year-1970)&0x7F) << 9
    return result

def extdate(d_word):
    """Extract date from a given 16-bit BatStack header ``date word.''

Returns an instance of date (from datetime module)
"""
    day = d_word & 0x001F
    month = (d_word & 0x01E0) >> 5
    year = 1970 + ((d_word & 0xFE00) >> 9)
    d = date(year, month, day)
    return d

def read_chanmap( fname ):
    """Read plaintext channel map file.

Supports either manual or automatic addressing. This is set by
considering the number of elements in the first row of the
file. If there are 5, then we assume manual and use the first
element of every row as the address. If there are 4, then we
assume automatic and begin with Stack of first row having address
1, second row 2, and so on.

Note that, in manual mode, we assume addresses are given in
hexadecimal format; e.g., 0x0a is read as 10 (base 10). The '0x'
prefix is optional.

Returns a dictionary with keys corresponding to Stack addresses
and values being lists (of length 4, always) where index in list
corresponds to local channel number and actual value is global
(i.e. system-wide for your Array implementation) channel.

On error, an empty dictionary is returned.
"""
    try:
        f = open(fname, 'rU')
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


class BSArrayFile:
    """Class that embodies standard Array data files

Includes header information, metadata, etc. and the data itself.
See the BatStack reference manual for the file specification.  If
given a file name fname, then the object attempts to load fname as
an Array data file; in this case, the argument param_fname is
ignored.  If fname is None (default), then try to read parameters
file param_fname; if param_fname is None (default), then store
some ``empty'' values in the object parameter fields (e.g.,
num_mics := 0).

Internal notes: Data should be saved as a dictionary of ndarrays
(type defined in NumPy), with key values of the channel
number. Sample values are each stored as u16 (i.e. dtype.uint16 in
NumPy terminology).
"""
    def __init__(self, fname=None, param_fname=None):
        # Internal parameters
        self.known_versions = [1, 2]

        # Default field values
        self.version = 2
        self.recording_date = date(1970, 1, 1) # The Epoch is default
        self.trial_number = 0
        self.num_mics = 0
        self.sample_period = np.array([3.75e-6])
        self.post_trigger_samps = 0
        self.notes = ''
        self.data = dict()

        # Handle arguments
        if fname is not None:
            self.readfile(fname)
        elif param_fname is not None:
            self.parse_paramfile(param_fname)

    def readfile(self, fname):
        """Read Array data file (conformant to specs).

See BatStack reference manual for file specifications. The
heavy-lifting happens in unpack_arrdata (called within readfile),
where the channel data are pulled in and organized into a
dictionary.

Returns True on success; False on failure.

On failure, it should be that the attributes of this instance of
BSArrayFile are as they were before calling this
method. (i.e. failures are ``clean'').
"""
        try:
            f = open(fname, 'rb')
        except:
            print 'Error: could not open %s for reading' % fname
            return False
        version = struct.unpack('b', f.read(1))[0] # Get version byte
        if version not in self.known_versions:
            print 'Error: unrecognized version spec: %d' % version
            f.close()
            return False
        try:
            hdr_tup = struct.unpack('<HbbHL', f.read(10))
        except:
            print 'Error while unpacking file header.'
            f.close()
            return False
        recording_date = extdate(hdr_tup[0])
        trial_number = hdr_tup[1]
        num_mics = hdr_tup[2]
        sample_period = np.array([hdr_tup[3]*1e-8])
        post_trigger_samps = hdr_tup[4]
        try:
            notes = f.read(128)
        except:
            print 'Error while reading notes string from file header.'
            f.close()
            return False
        notes = notes.rstrip('\x00') # Trim trailing zeros
        if num_mics < 1:
            print 'Error: in header, bad number of mics: %d' % num_mics
            f.close()
            return False
        data = self.unpack_arrdata(f.read(), num_mics, version=version)
        if data == -1:
            print 'Error while reading channel data.'
            f.close()
            return False
        if version == 1:
            self.version = 2 # Upgrade
        else:
            self.version = version
        self.recording_date = recording_date
        self.trial_number = trial_number
        self.num_mics = num_mics
        self.sample_period = sample_period.copy()
        self.post_trigger_samps = post_trigger_samps
        self.notes = notes
        self.data = data
        f.close()
        return True

    def unpack_arrdata(self, data_str, num_mics=16, chan_len=None, trim_flag=True, version=None):
        """Read array data from disk.

Converts the given string, which was loaded from an Array data
file IN ITS ENTIRETY... this could be a problem in some systems,
in some contexts. The alternative is to progressively read the
file from disk, i.e. work with blocks instead of all-at-once.

If trim_flag is True (default), then only channels with nonzero
values are stored.

chan_len is the number of elements (i.e., number of samples) per
channel. If None (default), then this is guessed using num_mics
(i.e. number of microphone channels) and the length of data_str
(i.e. the raw file data string).

If version is None (default), then use the most recent version
available... this is dangerous! In general you should specify
which version based on contents of the file header.

On success, returns a dictionary with keys of channel numbers and
values as ndarrays (type defined in NumPy).  Note that this how we
expect the ``data'' attribute of BSArrayFile instances to look
(i.e., you may simply save the result of unpack_arrdata directly
to self.data)

On error, returns -1.
"""
        if version is None:
            version = self.known_versions[-1]
        if len(data_str) < 2 or num_mics < 1 or \
           (chan_len is not None and chan_len < 1) or \
           version < 0: # Sanity check
            return -1
        if chan_len is None:
            chan_len = len(data_str)/2/num_mics
        # Read channel data in blocks, as per file spec
        if version == 1:
            block_size = 1048576*num_mics # Internal parameter (depends on num_mics)
            if not trim_flag:
                data = dict([(k, np.zeros(shape=(chan_len,1), dtype='uint16')) for k in range(1, num_mics+1)])
            else:
                data = dict()
            str_ind = 0 # Track position in data_str
            chan_ind = -1 # Index across channels
            while str_ind < len(data_str):
                if len(data_str)-str_ind < block_size:
                    block_size = len(data_str)-str_ind
                part = struct.unpack('<'+'H'*(block_size/2), data_str[str_ind:str_ind+block_size])
                current_mic = num_mics # Force first iteration to increment chan_ind
                for val in part:
                    current_mic += 1
                    if current_mic > num_mics:
                        chan_ind += 1
                        current_mic = 1
                    if val != 0:
                        if current_mic not in data.keys():
                            data[current_mic] = np.zeros(shape=(chan_len,1), dtype='uint16')
                        data[current_mic][chan_ind] = val
                str_ind += block_size
        elif version == 2:
            if not trim_flag:
                data = dict([(k, np.zeros(shape=(chan_len,1), dtype='uint16')) for k in range(1, num_mics+1)])
            else:
                data = dict()
            str_ind = 0 # Track position in data_str
            block_size = chan_len*2
            current_mic = 1 # We assume channel numbering begins at 1
            while str_ind < len(data_str) and current_mic <= num_mics:
                if len(data_str)-str_ind < block_size:
                    block_size = len(data_str)-str_ind
                    print 'Warning: early truncation on channel %d' % current_mic
                chandata_tup = struct.unpack('<'+'H'*(block_size/2), data_str[str_ind:str_ind+block_size])
                nonzero_found = False
                for v in chandata_tup:
                    if v != 0:
                        nonzero_found = True
                        break
                if nonzero_found:
                    data[current_mic] = np.array(chandata_tup, dtype='uint16')
                current_mic += 1
                str_ind += block_size
        else: # Unknown version; panic
            print 'Unsupported version: %d' % version
            return -1
        return data

    def writefile(self, fname, prevent_overwrite=True):
        """Write Array data file (conformant to specs).

See BatStack reference manual for file specifications. The flag
prevent_overwrite is used to avoid accidentally overwriting (hence,
deleting previous contents) an existing similarly named file.

Returns True on success; False on failure.
"""
        if prevent_overwrite:
            try:
                f = open(fname, 'r')
            except IOError: # This existence-check technique is a bit sloppy
                pass
            else:
                f.close()
                print 'Error: file %s already exists.' % fname
                return False
        
        # Build the header to-be-written
        hdr_str = struct.pack('<bHbbHL', self.version,
                              gendate(self.recording_date),
                              self.trial_number,
                              self.num_mics,
                              int(self.sample_period[0]*1e8), # Convert to 10 ns units
                              self.post_trigger_samps)
        if len(self.notes) > 128:
            notes = self.notes[:128]
        else:
            notes = self.notes + chr(0)*(128-len(self.notes)) # Pad with zeros
        hdr_str += notes
        
        if len(self.data) > 0:
            data_str = self.pack_arrdata(version=self.version)
            if data_str == -1:
                print 'Error: failed to pack array data.'
                return False
        try:
            f = open(fname, 'wb')
        except:
            print 'Error: could not open %s for writing.' % fname
            return False
        try:
            f.write(hdr_str) # Write header
            if len(self.data) > 0:
                f.write(data_str) # Write data
            else:
                print 'Warning: no data (hence, only writing file header)'
        except:
            print 'Error while writing to file.'
            f.close()
            return False
        f.close()
        return True

    def copy_hdr(self, another_bsArrayFile):
        """Copy header from another object, leave data field untouched.

This should be made into a special method, e.g. __copy__.
Returns nothing.
"""
        self.version = another_bsArrayFile.version
        self.recording_date = date(another_bsArrayFile.recording_date.year,
                                   another_bsArrayFile.recording_date.month,
                                   another_bsArrayFile.recording_date.day)
        self.trial_number = another_bsArrayFile.trial_number
        self.num_mics = another_bsArrayFile.num_mics
        self.sample_period = another_bsArrayFile.sample_period.copy()
        self.post_trigger_samps = another_bsArrayFile.post_trigger_samps
        self.notes = another_bsArrayFile.notes
        return

    def set_params(self, param_dict):
        """Set parameter/header values using a dictionary.

The key is a string for the particular field.  Currently this must
match exactly the attribute name.  If the value is None, then the
field is left untouched (i.e. the existing value remains).  If the
value is non-None, then the value is copied as-is into the
attribute.

Returns nothing.
"""
        # NOT IMPLEMENTED YET
        pass
        return None

    def parse_paramfile(self, param_fname, dumpsd_style=False):
        """Parse an Array data parameters/header notes file (plaintext).

...with which to populate the header of an Array data file format.
The argument dumpsd_style indicates whether to handle a "params"
file as created by dumpsd (utility program for reading SD cards
that have Stack data). This is not currently implemented.

Instead, we use <field name>: <value>

At most one <field name>: <value> should appear per line. Empty
lines are ignored. <value> should be contained on a single
line. Field names must match the names of corresponding members of
this BSArrayFile class; indeed, this is done somewhat blindly
using getattr, so be careful. In the case of the trial notes, the
string should be demarcated by double quotes, i.e. "

On success, returns True (and this object's field are updated
accordingly); on failure, False.
"""
        line_num = 0
        try:
            f = open(param_fname, 'rU')
        except:
            print 'Error: could not open %s for reading.' % param_fname
            return False
        for line in f:
            line_num += 1
            ind = line.find(':')
            if ind > -1:
                if line[:ind] in dir(self):
                    if line[:ind] == 'version':
                        self.version = int(line[ind+1:])
                    elif line[:ind] == 'trial_number':
                        self.trial_number = int(line[ind+1:])
                    elif line[:ind] == 'num_mics':
                        self.num_mics = int(line[ind+1:])
                    elif line[:ind] == 'post_trigger_samps':
                        self.post_trigger_samps = int(line[ind+1:])
                    elif line[:ind] == 'notes':
                        self.notes = line[ind+1:] # This could be a security hole?
                    #if  line[:ind] in ['version', 'trial_number', 'num_mics',
                    #                   'post_trigger_samps']: # treat Int casts
                    #    getattr(self, line[:ind]) = int(line[ind+1:])
                    elif line[:ind] == 'sample_period': # treat ndarray (NumPy)
                        self.sample_period = np.fromstring(line[ind+1:], dtype=np.float64, sep=', ')
                    elif line[:ind] == 'recording_date': # treat datestring
                        datestr = line[ind+1:].split() # Try whitespace first
                        if len(datestr) != 3:
                            print 'Error on line %d: cannot parse date string' % line_num
                            return False
                        else:
                            self.recording_date = date(int(datestr[0]),
                                                       int(datestr[1]),
                                                       int(datestr[2]))
                    else:
                        print "Error on line %d: unrecognized field name ``%s''" % (line_num, line[:ind])
                        return False
        f.close()
        return True

    def pack_arrdata(self, num_mics=None, version=None, data=None):
        """Prep array data for storage on disk.

Assumes given data is as stored in BSArrayFile, i.e. dictionary
keyed by channel number, etc.  The argument num_mics sets the
total number of microphone channels. If this is None (default),
then use maximum of self.num_mics (if available) and
max(data.keys()). Otherwise, use specified number, ignoring any
data.keys() > num_mics.

If no data is given, then uses data dictionary as part of current
object instance. Otherwise, given data dictionary is used. The
goal is to allow use of this method external to the BSArrayFile
class.

If version is None (default), then use the most recent version
available... this is dangerous! In general you should specify
which version based on contents of the file header.

Returns result as a string (ready to be used in a call to
file.write).  Notes that channel numbers less than num_mics but
not in data.keys() will be filled with zero.

On error, returns -1.
"""
        if version is None:
            version = self.known_versions[-1]
        if data is None:
            data = self.data
        elif not isinstance(data, dict) or len(data) < 1:
            # Only dictionaries are accepted (we do little other error-checking than this).
            return -1
        if num_mics is None:
            num_mics = np.max(data.keys())
            if getattr(self, 'num_mics', -1) > 0:
                num_mics = np.max([self.num_mics, num_mics])
        else:
            num_mics = np.array([num_mics], dtype='uint16') # To ensure consistent type
        if len(data) < 1:
            # Disallow empty trials (or at least, this behaviour can
            # be achieved, but only outside of pack_arrdata.
            return -1 
        
        # Verify that length of trials in data is equal.
        # If not, abort.
        chan_len = len(data[data.keys()[0]])
        for v in data.values():
            if len(v) != chan_len:
                return -1

        # Finally generate the data string according to file spec version
        if version == 1:
            data_str = ''
            for i in range(chan_len):
                for k in range(1, num_mics+1): # N.B., data is interleaved
                    if k in data.keys():
                        data_str += struct.pack('<H', int(data[k][i]))
                    else:
                        data_str += '\x00\x00'
        elif version == 2:
            data_str = ''
            for k in range(1, num_mics+1):
                if k in data.keys():
                    for i in range(chan_len):
                        data_str += struct.pack('<H', int(data[k][i]))
                else:
                    data_str += '\x00\x00'*chan_len
        else:
            print 'Error: cannot pack data; unsupported version: %d' % version
            return -1
        return data_str


# For use at the command-line,
if __name__ == "__main__":
    print 'Reading...'
    bsaf = BSArrayFile(sys.argv[1])
    print 'Writing...'
    bsaf.writefile('test.bin', prevent_overwrite=False)
    
    #di = read_chanmap( sys.argv[1] )
    #for (k,v) in di.items():
    #    print '%d: %s' % (k, str(v))
