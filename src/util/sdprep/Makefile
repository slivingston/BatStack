CC = gcc
COPTS = -pedantic -Wall

OBJS = sdprep

all: $(OBJS)

sdprep: sdprep.o
	$(CC) -o $@ $<

sdprep.o: sdprep.c
	$(CC) -c $< $(COPTS)

clean:
	rm -f *~ *.o $(OBJS)