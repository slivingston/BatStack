#!/usr/bin/env python
#
# Generate a 16-bit date conforming to BatStack header format, given
# a numeric date string in form YYYY MM DD.
# For example, April 15, 2010 would be
#
# ./gendate.py 2010 4 15
#
#
# Scott Livingston
# April 2010


import sys

if len(sys.argv) != 4:
    print "Usage: %s $year $month $day" % sys.argv[0]
    exit(0)

try:
    year  = int(sys.argv[1])
    month = int(sys.argv[2])
    day   = int(sys.argv[3])
except ValueError:
    print "Invalid arguments given."
    exit(1)

result = day&0x1F
result |= (month&0xF) << 5
result |= ((year-1970)&0x7F) << 9

print "0x%04X" % result
