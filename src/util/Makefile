# Build utilities for BatStack.
#
# Scott Livingston
# May 2010.

BASEDIR=/home/scott/opt/pic30
CC=pic30-coff-gcc
LD=pic30-coff-ld
B2H=pic30-coff-bin2hex
CFLAGS=-I../firmware/include


memcheck.hex: memcheck.c
	$(CC) -mresource=$(BASEDIR)/c30_device.info -mcpu=33FJ128GP710 -merrata=psv_trap $(CFLAGS) -c $<
	$(LD) *.o -o memcheck.cof --script stackutils.gld
	$(B2H) memcheck.cof

clean:
	rm -f *~ *.o *.cof *.hex


