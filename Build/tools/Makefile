#
# Makefile for ndepgen
#

ndepgen: ndepgen.c
	$(CC) -O2 -Wall -g -o ndepgen ndepgen.c

install: ndepgen
	ginstall -s ndepgen $(HOME)/bin

clean:
	rm -f *.o ndepgen
