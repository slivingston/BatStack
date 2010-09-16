pic30-gcc -mcpu=33FJ128GP710 -c sdtest.c
pic30-ld sdtest.o -o sdtest.cof --script sdspils.gld
pic30-bin2hex sdtest.cof
