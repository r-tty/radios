#******************************************************************************#
#  Makefile for RSL (Radiant System Loader) and DOSKLD (DOS Kernel Loader).
#  (c) 1999 RET & COM Research.
#******************************************************************************#


# --- Paths --- #
RADIOSPATH = /home/yuriz/radios
LIBPATH = /usr/local/lib/radios/16bit
OUTPATH = out

vpath %.rdl $(LIBPATH)
vpath %.rdm $(OUTPATH)


# --- Programs --- #
CC = cc -I/usr/include/cc386/raw -C+NX+F
AS = nasm -s -f rdf -p/usr/local/include/nasm/tasmlike.mac -o
LINK = ldrdf -2 -a 1 -j $(OUTPATH)/ -L $(LIBPATH)/ -s -xe
CONV = rdf2bin -o 0x100 -p 1


# --- Dependencies --- #

all: Makefile doskld.com

rsl.com: barekld.rdm rsl.rdm radiosld.rdm raw16.rdl
	$(LINK) -o rsl.rdx barekld.rdm rsl.rdm radiosld.rdm -lraw16.rdl
	$(CONV) rsl.rdx rsl.com
	rm rsl.rdx

doskld.com: doskld.rdm scfg.rdm radiosld.rdm raw16.rdl
	$(LINK) -o doskld.rdx doskld.rdm scfg.rdm radiosld.rdm -lraw16.rdl
	$(CONV) doskld.rdx doskld.com
	rm doskld.rdx


# --- Individual dependencies --- #

rsl.rdm: rsl.asm
	$(AS) $(OUTPATH)/rsl.rdm rsl.asm

rsl.asm: rsl.c
	$(CC) rsl.c

radiosld.rdm: radiosld.as
	$(AS) $(OUTPATH)/radiosld.rdm -i$(RADIOSPATH)/include/ radiosld.as

barekld.rdm: barekld.as
	$(AS) $(OUTPATH)/barekld.rdm barekld.as

doskld.rdm: doskld.as
	$(AS) $(OUTPATH)/doskld.rdm doskld.as

scfg.rdm: scfg.as
	$(AS) $(OUTPATH)/scfg.rdm scfg.as


# --- Delete junk --- #

clean:
	rm -f *.rdx
	rm -f *.com
