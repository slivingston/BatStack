# Pump message 0xDEAD 0xBEEF to SPI
#
# Scott Livingston
# 16 Apr 2010.

BASEDIR=/home/scott/opt/pic30
CC=pic30-coff-gcc
LD=pic30-coff-ld
B2H=pic30-coff-bin2hex


spipump.hex: spipump.c
	echo 'Making LED counter example...'
	$(CC) -mresource=$(BASEDIR)/c30_device.info -mcpu=33FJ128GP710 -merrata=psv_trap -c spipump.c
	$(LD) spipump.o -o spipump.cof --script spipumpls.gld 
	$(B2H) spipump.cof

clean:
	rm -f *~ *.o spipump.cof spipump.hex

