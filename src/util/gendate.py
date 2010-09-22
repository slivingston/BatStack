#!/usr/bin/env python
"""
Generate a 16-bit date conforming to BatStack header format.

The input should be given as a numeric date string in form YYYY MM DD.
For example, April 15, 2010 would be

./gendate.py 2010 4 15

If the script is called without arguments, then the date today (as
reported by the host system) is return.

Otherwise, a usage statement is printed.


Scott Livingston  <slivingston@caltech.edu>
Apr, Sep 2010.
"""


import sys
from datetime import date

if len(sys.argv) == 4:
    try:
        year  = int(sys.argv[1])
        month = int(sys.argv[2])
        day   = int(sys.argv[3])
        if year < 1970 or month < 0 or month > 12 or day < 1 or day > 31:
            raise ValueError
    except ValueError:
        print "Invalid arguments given."
        exit(1)
elif len(sys.argv) == 1:
    d = date.today()
    day = d.day
    month = d.month
    year = d.year
    print "Using today (i.e. %02d/%02d/%04d)" % (day, month, year)
else:
    print "Usage: %s [$year $month $day]" % sys.argv[0]
    exit(0)

result = day&0x1F
result |= (month&0xF) << 5
result |= ((year-1970)&0x7F) << 9

print "0x%04X" % result
