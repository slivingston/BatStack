# microphone localization for wideband array
# (part of BatStack project.)
#
# Scott Livingston
# May 2010.

BASEDIR=/home/scott/opt/pic30
CC=pic30-coff-gcc
LD=pic30-coff-ld
B2H=pic30-coff-bin2hex
MCU=24HJ12GP201

UTIL=micloc

$(UTIL).hex: $(UTIL).c
	$(CC) -mresource=$(BASEDIR)/c30_device.info -mcpu=$(MCU) -merrata=psv_trap -c $<
	$(LD) $(UTIL).o -o $(UTIL).cof --script $(UTIL)ls.gld 
	$(B2H) $(UTIL).cof

clean:
	rm -f *~ *.o $(UTIL).cof $(UTIL).hex
