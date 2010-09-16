del batstack.hex batstack.cof
pic30-gcc -mcpu=33FJ128GP710 -merrata=psv_trap -mconst-in-data -save-temps -c main.c utils.c sdspi.c
pic30-ld main.o utils.o sdspi.o -o batstack.cof --script batstackls.gld
pic30-bin2hex batstack.cof
