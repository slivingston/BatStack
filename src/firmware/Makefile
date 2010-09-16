# Build firmware for BatStack.
#
# Scott Livingston
# Mar-May,July 2010.

BASEDIR=/opt/pic_C30
CC=pic30-coff-gcc
LD=pic30-coff-ld
B2H=pic30-coff-bin2hex
CFLAGS=-Iinclude
LIBDIR=lib

CFILES=main.c $(LIBDIR)/utils.c $(LIBDIR)/sdspi.c $(LIBDIR)/env.c $(LIBDIR)/sdcard.c $(LIBDIR)/ints.c $(LIBDIR)/comm.c


batstack.hex: $(CFILES)
	echo 'Making BatStack firmware...'
	$(CC) -mresource=$(BASEDIR)/c30_device.info -mcpu=33FJ128GP710 -merrata=psv_trap -mlarge-code -mconst-in-data $(CFLAGS) -c $(CFILES)
	$(LD) *.o -o batstack.cof --script batstackls.gld
	$(B2H) batstack.cof

clean:
	rm -f *~ *.o batstack.cof batstack.hex

