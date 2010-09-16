CC = gcc
COPTS = -pedantic -Wall -g

OBJS = dumpsd

all: $(OBJS)

dumpsd: dumpsd.o
	$(CC) -o $@ $<

dumpsd.o: dumpsd.c
	$(CC) -c $< $(COPTS)

clean:
	rm -f *~ *.o $(OBJS)
