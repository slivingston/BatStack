# Build example LED counter for BatStack
#
# Scott Livingston
# Apr,July 2010.

BASEDIR=/opt/pic_C30
CC=pic30-coff-gcc
LD=pic30-coff-ld
B2H=pic30-coff-bin2hex

OBJ=ledcnt.hex ledcnt_40MHz.hex

all: $(OBJ)

ledcnt.hex: ledcnt.c
	echo 'Making LED counter example...'
	$(CC) -mresource=$(BASEDIR)/c30_device.info -mcpu=33FJ128GP710 -merrata=psv_trap -c $<
	$(LD) ledcnt.o -o ledcnt.cof --script ledcntls.gld 
	$(B2H) ledcnt.cof

ledcnt_40MHz.hex: ledcnt_40MHz.c
	echo 'Making LED counter example...'
	$(CC) -mresource=$(BASEDIR)/c30_device.info -mcpu=33FJ128GP710 -merrata=psv_trap -c $<
	$(LD) ledcnt_40MHz.o -o ledcnt_40MHz.cof --script ledcntls.gld 
	$(B2H) ledcnt_40MHz.cof

clean:
	rm -f *~ *.o ledcnt.cof ledcnt.hex ledcnt_40MHz.cof ledcnt_40MHz.hex

